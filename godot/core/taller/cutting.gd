## Taller · modelo de corte (unidad 5).
##
## Fuerza específica de corte de Kienzle con las correcciones del Tabellenbuch Zerspantechnik (TZ, pp. 206-208):
##   kc = kc1.1 / h^mc · Kγ · Kvc · Kver · Ksp
##   - h: espesor de viruta (mm). En torneado h = f·sen κ y b = ap/sen κ (TZ, p. 202).
##   - Kγ = 1 − (γ − γ0)/100, con γ0 = +6° en acero y +2° en fundición (TZ, p. 208).
##   - Kvc: por material de corte: HSS 1,2; metal duro 1,0; cerámica 0,85 (TZ, p. 208).
##   - Kver: desgaste, de 1,2 a 1,5 (TZ, p. 208; el ejemplo de esa página usa 1,2 con «desgaste ligero»).
##   - Ksp: recalcado de la viruta según el proceso: torneado exterior 1,0; cepillado y brochado 1,1; taladrado,
##     fresado y torneado interior 1,2; tronzado y ranurado 1,3 (TZ, p. 208).
## Fuerzas de avance y pasiva: Ff = A·kf1.1/h^mf, Fp = A·kp1.1/h^mp (TZ, p. 211; work_materials.gd).
## Potencia de corte Pc = Fc·vc y del motor Pc/η, con η = 0,7-0,85 (TZ, p. 212); por defecto 0,8, el mismo que
## usa Sandvik en su tabla de K.
## Fresado y taladrado: espesor medio de viruta, potencia neta, par y empuje de Sandvik Coromant (guía técnica
## de fresado de 2005 y fórmulas de taladrado); el espesor medio se calcula con la geometría exacta del contacto.
## Rugosidad teórica (cota ideal, solo la huella del radio de punta): Rt = f²/(8·rε) y Ra = f²/(18·√3·rε), que
## la bibliografía redondea a f²/(32·rε).
## Vida: Taylor vc·T^n = C (tool_materials.gd): siempre estimación. El desgaste que crece con el tiempo de corte (VB,
## Kver, rugosidad y fin de vida de ISO 3685) está en core/taller/wear.gd; cutting_model_worn aplica su Kver al modelo
## del torno. Seguro entre hilos: sin estado mutable (la tabla de cutting_model es de solo lectura).
## Calidad del resultado: la peor entre la de kc1.1 y mc, la de Kvc, la de Kver (el desgaste «medio» es una
## interpolación) y la de γ0 cuando γ ≠ γ0 (el TZ solo da γ0 para acero y fundición).
## Unidades: mm, N, N/mm² (= MPa), m/min, rpm, mm/min, kW, N·m, cm³/min, µm y min.
## Todo es determinista; los avisos van en español y con los números de js.gd.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")

## Kver por estado del filo. «ligero» y «fuerte» son los extremos del TZ (1,2 y 1,5); «nuevo» = 1 (las tablas de
## kc son de filo sin desgaste); «medio» es el punto medio (interpolación, estimación).
const WEAR_FACTORS := { "nuevo": 1.0, "ligero": 1.2, "medio": 1.35, "fuerte": 1.5 }
const WEAR_QUALITY := { "nuevo": "primary", "ligero": "primary", "medio": "estimate", "fuerte": "primary" }
## Ksp por proceso (TZ, p. 208)
const PROCESS_FACTORS := {
	"exterior": 1.0, "cepillado": 1.1, "brochado": 1.1, "taladrado": 1.2, "fresado": 1.2, "interior": 1.2,
	"tronzado": 1.3, "ranurado": 1.3,
}
## Materiales cuyo γ0 da el TZ (+6° acero, +2° fundición); en el resto es un supuesto
const GAMMA0_KINDS := ["acero", "inox", "fundicion"]
const ETA_DEFAULT := 0.8
## Intervalo de h de las tablas del TZ (pp. 209-210): fuera de él, kc es una extrapolación
const H_TABLE_MIN := 0.06
const H_TABLE_MAX := 1.6
## Por debajo de este espesor la ley de potencias se dispara (h → 0): se calcula kc con h = H_FLOOR
const H_FLOOR := 0.01
## Ángulo de punta de la broca helicoidal: 118°, el del TZ (p. 212)
const DRILL_POINT_DEG := 118.0
const NOSE_R_DEFAULT := 0.8
const SRC_TZ_KC := "Tabellenbuch Zerspantechnik (2015), pp. 206-211: kc de Kienzle con Kγ, Kvc, Kver y Ksp"
const SRC_TZ_POWER := "Tabellenbuch Zerspantechnik (2015), p. 212: Pc = Fc·vc; η = 0,7-0,85"
const SRC_SANDVIK_MILL := (
	"Sandvik Coromant, Metalcutting Technical Guide (D) Milling, 2005, pp. D23-D25: hm, Pc y Mγ = 1 − γ/100"
)
const SRC_SANDVIK_DRILL := (
	"Sandvik Coromant, fórmulas de taladrado: Pc = fn·vc·Dc·kc/240 000; Mc = Pc·30 000/(π·n); "
	+ "Ff ≈ 0,5·kc·(Dc/2)·fn·sen κr"
)
const SRC_ROUGH := (
	"Rugosidad teórica de la huella del radio de punta: Rt = f²/(8·rε) y Ra = f²/(18·√3·rε) ≈ f²/(32·rε) "
	+ "(geometría; cota ideal)"
)
const TURNING_KEYS := [
	"rpm", "vc", "h_mm", "b_mm", "a_mm2", "kc", "band", "kc_parts", "fc_n", "ff_n", "fp_n", "pc_kw", "pmotor_kw",
	"torque_nm", "q_cm3_min", "rt_um", "ra_um", "life_min", "quality", "ff_fp_quality", "life_quality",
]
const MILLING_KEYS := [
	"rpm", "vc", "vf_mm_min", "fz_mm", "hm_mm", "hex_mm", "zc", "kc", "band", "kc_parts", "fc_mean_n", "pc_kw",
	"pmotor_kw", "torque_nm", "q_cm3_min", "tooth_hz", "life_min", "quality", "life_quality",
]
const DRILLING_KEYS := [
	"rpm", "vc", "vf_mm_min", "h_mm", "kc", "band", "kc_parts", "fc_edge_n", "thrust_n", "torque_nm", "pc_kw",
	"pmotor_kw", "q_cm3_min", "life_min", "quality", "life_quality",
]

## Datos de cutting_model por pareja material-herramienta («work_id|tool_id»), calculados una sola vez al cargar el
## script para todas las parejas de los catálogos (que son constantes) y congelados con make_read_only(). Nadie los
## escribe después, así que varios hilos los leen a la vez sin cerrojos (CONTRATOS.md → «Rendimiento y multinúcleo»).
## Una pareja que no está en los catálogos se calcula en cada llamada (da ok = false) y no se guarda.
static var _model_table: Dictionary = _build_model_table()


## Fuerza específica de corte con las correcciones del TZ.
## p: { kc11, mc, h_mm, gamma_deg, gamma0_deg (6), tool_factor (Kvc, 1), wear_factor (Kver, 1),
##      process_factor (Ksp, 1) }
## Devuelve { kc, k (valor de tabla kc1.1/h^mc), Kh (= h^−mc), Kgamma, Kvc, Kver, Ksp }.
static func specific_cutting_force(p: Dictionary) -> Dictionary:
	var kc11: float = p["kc11"]
	var mc: float = p["mc"]
	var h: float = p["h_mm"]
	var gamma0: float = p.get("gamma0_deg", 6.0)
	var gamma: float = p.get("gamma_deg", gamma0)
	var k_vc: float = p.get("tool_factor", 1.0)
	var k_ver: float = p.get("wear_factor", 1.0)
	var k_sp: float = p.get("process_factor", 1.0)
	var k_h := pow(h, -mc)
	var k_gamma := 1.0 - (gamma - gamma0) / 100.0
	return {
		"kc": kc11 * k_h * k_gamma * k_vc * k_ver * k_sp,
		"k": kc11 * k_h,
		"Kh": k_h,
		"Kgamma": k_gamma,
		"Kvc": k_vc,
		"Kver": k_ver,
		"Ksp": k_sp,
	}


## Potencia de corte (kW) con Fc en N y vc en m/min: Pc = Fc·vc/60 000 (TZ, p. 212).
static func cutting_power_kw(fc_n: float, vc_m_min: float) -> float:
	return fc_n * vc_m_min / 60000.0


static func rpm_from_vc(vc_m_min: float, d_mm: float) -> float:
	if d_mm <= 0.0:
		return 0.0
	return vc_m_min * 1000.0 / (PI * d_mm)


static func vc_from_rpm(rpm: float, d_mm: float) -> float:
	return PI * d_mm * rpm / 1000.0


## Rugosidad teórica del torneado (µm), solo la huella del radio de punta: una cota ideal (el acabado real
## empeora con la vibración, el filo recrecido y el desgaste). valid = false si f > rε: entonces el perfil ya no
## lo forma solo el radio de punta y la fórmula deja de valer.
static func roughness(f_mm: float, nose_r_mm: float) -> Dictionary:
	if f_mm <= 0.0 or nose_r_mm <= 0.0:
		return { "rt_um": NAN, "ra_um": NAN, "ideal": true, "valid": false, "source": SRC_ROUGH }
	return {
		"rt_um": f_mm * f_mm / (8.0 * nose_r_mm) * 1000.0,
		"ra_um": f_mm * f_mm / (18.0 * sqrt(3.0) * nose_r_mm) * 1000.0,
		"ideal": true,
		"valid": f_mm <= nose_r_mm,
		"source": SRC_ROUGH,
	}


## Vida de Taylor (min): vc·T^n = C → T = (C/vc)^(1/n). Estimación: ver tool_materials.gd.
static func taylor_life(vc_m_min: float, n: float, c: float) -> float:
	if vc_m_min <= 0.0:
		return INF
	return pow(c / vc_m_min, 1.0 / n)


## Kver a partir de un nombre de WEAR_FACTORS (sin distinguir mayúsculas) o de un número; 1 si no se conoce.
static func wear_factor(wear: Variant) -> float:
	return float(_wear(wear, [])["k"])


## La peor de dos calidades (primary < secondary < estimate).
static func worst_quality(a: String, b: String) -> String:
	var order: Array = WorkMaterials.QUALITIES
	return a if order.find(a) >= order.find(b) else b


## Modelo de corte que se inyecta en el torno (CONTRATOS.md):
##   Callable(work_id, tool_id, h_mm, b_mm, vc) -> { kc, fc_n, ... }
## Usa el filo nuevo (Kver = 1), el desprendimiento base del material (Kγ = 1) y el torneado exterior (Ksp = 1).
## Añade ff_n y fp_n, ok, vc_ok (vc dentro del intervalo orientativo de la herramienta) y quality.
## Si el material no tiene kc (madera, plásticos, vidrio, piedra) o no existe: kc y fuerzas 0 (finitas, para que
## nada propague NaN al torno ni al sonido), ok = false y reason con el motivo, que el torno debe enseñar.
## Con h o b ≤ 0 devuelve fuerzas nulas; con h < H_FLOOR calcula kc con H_FLOOR (Fc sigue siendo kc·b·h).
static func cutting_model(work_id: String, tool_id: String, h_mm: float, b_mm: float, vc: float) -> Dictionary:
	var e: Dictionary = _model_table.get(work_id + "|" + tool_id, {})
	if e.is_empty():
		e = _model_entry(work_id, tool_id)
	if not e["ok"]:
		return {
			"kc": 0.0, "fc_n": 0.0, "ff_n": 0.0, "fp_n": 0.0, "ok": false, "vc_ok": false, "quality": null,
			"reason": e["reason"],
		}
	var h_eff := maxf(h_mm, H_FLOOR)
	var kc: float = float(e["kc11"]) * pow(h_eff, -float(e["mc"])) * float(e["kvc"])
	var area := maxf(h_mm, 0.0) * maxf(b_mm, 0.0)
	var side := _side_forces(e, area, h_eff)
	return {
		"kc": kc,
		"fc_n": kc * area,
		"ff_n": side.x,
		"fp_n": side.y,
		"ok": true,
		"vc_ok": vc >= float(e["vc_lo"]) and vc <= float(e["vc_hi"]),
		"quality": e["quality"],
	}


## El Callable listo para inyectar en el torno.
static func model_callable() -> Callable:
	return Callable(_script(), "cutting_model")


## cutting_model con el filo gastado (fase 2): kc y Fc por Kver (Wear.kver_for_vb en core/taller/wear.gd), como hace el
## TZ con kc; Ff y Fp no cambian (el TZ no los corrige; Wear.effects da los factores del caso medido). Kver se limita al
## intervalo del TZ, de 1 a 1,5. Con kver = 1 es cutting_model tal cual. Añade `kver`; con Kver ≠ 1 la calidad pasa a
## ser una estimación.
static func cutting_model_worn(work_id: String, tool_id: String, h_mm: float, b_mm: float, vc: float,
		kver: float = 1.0) -> Dictionary:
	var r := cutting_model(work_id, tool_id, h_mm, b_mm, vc)
	var k := clampf(kver, 1.0, WEAR_FACTORS["fuerte"]) if not is_nan(kver) else 1.0
	r["kver"] = k
	if not r["ok"] or k == 1.0:
		return r
	r["kc"] = float(r["kc"]) * k
	r["fc_n"] = float(r["fc_n"]) * k
	r["quality"] = worst_quality(str(r["quality"]), "estimate")
	return r


## Este mismo script, para los Callable de sus funciones estáticas.
static func _script() -> Script:
	return load("res://core/taller/cutting.gd")


## El Callable del modelo con el filo gastado para el torno (misma firma que model_callable(): el Kver va ligado). Se
## vuelve a pedir cuando cambia el desgaste.
static func model_callable_worn(kver: float) -> Callable:
	return Callable(_script(), "cutting_model_worn").bind(kver)


## Torneado cilíndrico exterior.
## p: { work_id, tool_id, d_mm, vc | rpm, f_mm_rev, ap_mm, kappa_deg (90), gamma_deg (γ0 del material),
##      nose_r_mm (0,8), wear ("nuevo" | "ligero" | "medio" | "fuerte" | Kver), process ("exterior"),
##      machine: { pmax_kw, rpm_max, eta (0,8) } }
## Devuelve TURNING_KEYS + { overload, rpm_limited, sources, warnings }: rpm, vc, h_mm, b_mm, a_mm2, kc, band,
##   kc_parts, fc_n, ff_n, fp_n, pc_kw, pmotor_kw, torque_nm, q_cm3_min, rt_um, ra_um, life_min, quality,
##   ff_fp_quality, life_quality. Sin kc (materiales no metálicos) o sin giro, las fuerzas, potencias y el par
##   valen null.
static func turning(p: Dictionary) -> Dictionary:
	var out := _start(TURNING_KEYS)
	var warnings: Array[String] = out["warnings"]
	var sources: Array[String] = out["sources"]
	var work := WorkMaterials.get_material(str(p.get("work_id", "")))
	var tool := ToolMaterials.get_tool(str(p.get("tool_id", "")))
	if work.is_empty() or tool.is_empty():
		warnings.append("Material o herramienta desconocidos.")
		return out
	var d := float(p.get("d_mm", 0.0))
	var f := float(p.get("f_mm_rev", 0.0))
	var ap := float(p.get("ap_mm", 0.0))
	var kappa := float(p.get("kappa_deg", 90.0))
	var nose_r := float(p.get("nose_r_mm", NOSE_R_DEFAULT))
	var machine := _dict(p, "machine")
	var eta := float(machine.get("eta", ETA_DEFAULT))
	if d <= 0.0 or f <= 0.0 or ap <= 0.0 or kappa <= 0.0 or kappa >= 180.0:
		warnings.append("Faltan datos: el diámetro, el avance, la profundidad y el ángulo de posición tienen que "
			+ "ser positivos.")
		return out
	if ap > d / 2.0:
		warnings.append("La profundidad de pasada (%s mm) supera el radio de la pieza (%s mm)." % [
			Js.to_fixed(ap, 2), Js.to_fixed(d / 2.0, 2)])
	var s := sin(deg_to_rad(kappa))
	var h := f * s
	var a := ap * f
	out["h_mm"] = h
	out["b_mm"] = ap / s
	out["a_mm2"] = a
	var rough := roughness(f, nose_r)
	out["rt_um"] = rough["rt_um"]
	out["ra_um"] = rough["ra_um"]
	sources.append(SRC_ROUGH)
	if not rough["valid"]:
		warnings.append("El avance (%s mm) supera el radio de punta (%s mm): la rugosidad teórica deja de valer." % [
			Js.to_fixed(f, 2), Js.to_fixed(nose_r, 2)])
	var sp := _spindle(p, d, machine, warnings)
	var vc: float = sp["vc"]
	out["rpm"] = sp["rpm"]
	out["vc"] = vc
	out["rpm_limited"] = sp["limited"]
	if float(sp["rpm"]) <= 0.0:
		return out
	out["q_cm3_min"] = a * vc  # Qw = ap·f·vc (TZ, p. 203): mm²·m/min = cm³/min
	if work["kc"] == null:
		warnings.append("Sin fuerza de corte para %s: %s" % [work["name"], work["kc_reason"]])
		return out
	_tool_checks(tool, work, vc, warnings)
	var ksp := _process_factor(p, "exterior", warnings)
	var kr := _kc_result(work, tool, h, p.get("gamma_deg"), _wear(p.get("wear", "nuevo"), warnings), ksp, warnings)
	var kc: float = kr["kc"]
	var h_eff := maxf(h, H_FLOOR)
	var fc := a * kc
	var fcomp := WorkMaterials.force_components(work)
	var side := _side_forces(fcomp, a, h_eff)
	out["kc"] = kc
	out["band"] = kr["band"]
	out["kc_parts"] = kr["parts"]
	out["fc_n"] = fc
	out["ff_n"] = side.x
	out["fp_n"] = side.y
	out["ff_fp_quality"] = fcomp["quality"]
	var pc := cutting_power_kw(fc, vc)
	out["pc_kw"] = pc
	out["pmotor_kw"] = pc / eta
	out["torque_nm"] = fc * d / 2000.0
	out["quality"] = kr["quality"]
	sources.append(SRC_TZ_KC)
	sources.append(str(work["kc"]["source"]))
	sources.append(str(fcomp["source"]))
	sources.append(SRC_TZ_POWER)
	_life(out, tool, work, vc, warnings, sources)
	_overload(out, machine, warnings)
	return out


## Fresado frontal o lateral con una fresa de plaquitas.
## p: { work_id, tool_id, dc_mm, z, vc | rpm, fz_mm y/o vf_mm_min, ap_mm, ae_mm, kappa_deg (90), gamma_deg,
##      centered (true: fresa centrada sobre el ancho ae; false: fresado lateral desde un borde), wear, machine,
##      kc_n_mm2 (opcional: kc medido o publicado, a γ0) con gamma0_deg (0) y kc_quality }
## Con fz_mm y vf_mm_min a la vez, el giro sale de n = vf/(z·fz) y se ignoran vc y rpm.
## Sin kc_n_mm2, kc sale del TZ con h = hm y Ksp = 1,2 (fresado). Con kc_n_mm2 solo se aplican Kγ y Kver: es
## el camino para comprobar un caso publicado con su propio kc.
## Devuelve MILLING_KEYS + { overload, rpm_limited, sources, warnings }.
static func milling(p: Dictionary) -> Dictionary:
	var out := _start(MILLING_KEYS)
	var warnings: Array[String] = out["warnings"]
	var sources: Array[String] = out["sources"]
	var work := WorkMaterials.get_material(str(p.get("work_id", "")))
	var tool := ToolMaterials.get_tool(str(p.get("tool_id", "")))
	var has_kc: bool = p.get("kc_n_mm2") != null
	if tool.is_empty() or (work.is_empty() and not has_kc):
		warnings.append("Material o herramienta desconocidos.")
		return out
	var dc := float(p.get("dc_mm", 0.0))
	var z := int(p.get("z", 1))
	var ap := float(p.get("ap_mm", 0.0))
	var ae := float(p.get("ae_mm", 0.0))
	var kappa := float(p.get("kappa_deg", 90.0))
	var machine := _dict(p, "machine")
	var eta := float(machine.get("eta", ETA_DEFAULT))
	if dc <= 0.0 or z < 1 or ap <= 0.0 or ae <= 0.0 or kappa <= 0.0 or kappa >= 180.0:
		warnings.append("Faltan datos: el diámetro, los dientes, ap, ae y el ángulo de posición tienen que ser "
			+ "positivos.")
		return out
	if ae > dc:
		warnings.append("El ancho de corte (%s mm) supera el diámetro de la fresa: se limita a %s mm." % [
			Js.to_fixed(ae, 1), Js.to_fixed(dc, 1)])
		ae = dc
	var feed := _mill_feed(p, dc, z, machine, warnings)
	var rpm: float = feed["rpm"]
	var vc: float = feed["vc"]
	var fz: float = feed["fz"]
	var vf: float = feed["vf"]
	if rpm <= 0.0 or fz <= 0.0:
		warnings.append("Faltan datos: hace falta la velocidad (vc o rpm) y el avance (fz o vf).")
		return out
	var eng := _engagement(ae, dc, bool(p.get("centered", true)))
	var sk := sin(deg_to_rad(kappa))
	var hm := fz * sk * float(eng["mean_sin"])
	out["rpm"] = rpm
	out["vc"] = vc
	out["rpm_limited"] = feed["limited"]
	out["vf_mm_min"] = vf
	out["fz_mm"] = fz
	out["hm_mm"] = hm
	out["hex_mm"] = fz * sk * float(eng["max_sin"])
	out["zc"] = z * (float(eng["phi2"]) - float(eng["phi1"])) / TAU
	out["q_cm3_min"] = ap * ae * vf / 1000.0
	out["tooth_hz"] = z * rpm / 60.0
	sources.append(SRC_SANDVIK_MILL)
	if not work.is_empty():
		_tool_checks(tool, work, vc, warnings)
	var wear := _wear(p.get("wear", "nuevo"), warnings)
	var kc := 0.0
	if has_kc:
		var g0 := float(p.get("gamma0_deg", 0.0))
		var r := specific_cutting_force({
			"kc11": float(p["kc_n_mm2"]), "mc": 0.0, "h_mm": 1.0, "gamma_deg": float(p.get("gamma_deg", g0)),
			"gamma0_deg": g0, "wear_factor": wear["k"],
		})
		kc = r["kc"]
		out["band"] = [kc, kc]
		out["kc_parts"] = r
		out["quality"] = str(p.get("kc_quality", "secondary"))
	else:
		if work["kc"] == null:
			warnings.append("Sin fuerza de corte para %s: %s" % [work["name"], work["kc_reason"]])
			return out
		var kr := _kc_result(work, tool, hm, p.get("gamma_deg"), wear, PROCESS_FACTORS["fresado"], warnings)
		kc = kr["kc"]
		out["band"] = kr["band"]
		out["kc_parts"] = kr["parts"]
		out["quality"] = kr["quality"]
		sources.append(SRC_TZ_KC)
		sources.append(str(work["kc"]["source"]))
	var pc := ap * ae * vf * kc / 6.0e7  # Pc = ap·ae·vf·kc/(60·10⁶) (Sandvik)
	var torque := pc * 30000.0 / (PI * rpm)
	out["kc"] = kc
	out["pc_kw"] = pc
	out["pmotor_kw"] = pc / eta
	out["torque_nm"] = torque
	out["fc_mean_n"] = torque * 2000.0 / dc
	if not work.is_empty():
		_life(out, tool, work, vc, warnings, sources)
	_overload(out, machine, warnings)
	return out


## Taladrado con broca helicoidal de dos filos.
## p: { work_id, tool_id, d_mm, vc | rpm, f_mm_rev, point_angle_deg (118), gamma_deg, wear, machine }
## Cada filo corta A = D·f/4 con h = (f/2)·sen(σ/2); Ksp = 1,2 (TZ). Par: dos filos a D/4 del eje.
## Devuelve DRILLING_KEYS + { overload, rpm_limited, sources, warnings }.
static func drilling(p: Dictionary) -> Dictionary:
	var out := _start(DRILLING_KEYS)
	var warnings: Array[String] = out["warnings"]
	var sources: Array[String] = out["sources"]
	var work := WorkMaterials.get_material(str(p.get("work_id", "")))
	var tool := ToolMaterials.get_tool(str(p.get("tool_id", "")))
	if work.is_empty() or tool.is_empty():
		warnings.append("Material o herramienta desconocidos.")
		return out
	var d := float(p.get("d_mm", 0.0))
	var f := float(p.get("f_mm_rev", 0.0))
	var sigma := float(p.get("point_angle_deg", DRILL_POINT_DEG))
	var machine := _dict(p, "machine")
	var eta := float(machine.get("eta", ETA_DEFAULT))
	if d <= 0.0 or f <= 0.0 or sigma <= 0.0 or sigma >= 180.0:
		warnings.append("Faltan datos: el diámetro, el avance y el ángulo de punta tienen que ser positivos.")
		return out
	var s := sin(deg_to_rad(sigma / 2.0))
	var h := f / 2.0 * s
	out["h_mm"] = h
	var sp := _spindle(p, d, machine, warnings)
	var vc: float = sp["vc"]
	out["rpm"] = sp["rpm"]
	out["vc"] = vc
	out["rpm_limited"] = sp["limited"]
	if float(sp["rpm"]) <= 0.0:
		return out
	out["vf_mm_min"] = f * float(sp["rpm"])
	out["q_cm3_min"] = d * f * vc / 4.0
	if work["kc"] == null:
		warnings.append("Sin fuerza de corte para %s: %s" % [work["name"], work["kc_reason"]])
		return out
	_tool_checks(tool, work, vc, warnings)
	var wear := _wear(p.get("wear", "nuevo"), warnings)
	var kr := _kc_result(work, tool, h, p.get("gamma_deg"), wear, PROCESS_FACTORS["taladrado"], warnings)
	var kc: float = kr["kc"]
	var fc_edge := kc * d * f / 4.0
	var pc := cutting_power_kw(fc_edge, vc)  # = fn·vc·D·kc/240 000 (Sandvik)
	out["kc"] = kc
	out["band"] = kr["band"]
	out["kc_parts"] = kr["parts"]
	out["fc_edge_n"] = fc_edge
	out["torque_nm"] = fc_edge * d / 2000.0
	out["thrust_n"] = 0.5 * kc * (d / 2.0) * f * s
	out["pc_kw"] = pc
	out["pmotor_kw"] = pc / eta
	out["quality"] = kr["quality"]
	sources.append(SRC_TZ_KC)
	sources.append(str(work["kc"]["source"]))
	sources.append(SRC_SANDVIK_DRILL)
	_life(out, tool, work, vc, warnings, sources)
	_overload(out, machine, warnings)
	return out


# --- auxiliares ---------------------------------------------------------------------------------------------


## Resultado vacío: las claves a null, sin sobrecarga ni tope de giro, y listas de fuentes y avisos.
static func _start(keys: Array) -> Dictionary:
	var out := {}
	for k in keys:
		out[k] = null
	var sources: Array[String] = []
	var warnings: Array[String] = []
	out["overload"] = false
	out["rpm_limited"] = false
	out["sources"] = sources
	out["warnings"] = warnings
	return out


## p[key] si es un diccionario; {} si falta o es null.
static func _dict(p: Dictionary, key: String) -> Dictionary:
	var v = p.get(key)
	return v if v is Dictionary else {}


## Kver y su calidad: { k, quality }. Nombres de WEAR_FACTORS sin distinguir mayúsculas o un número: 1 o dentro del
## intervalo 1,2-1,5 del TZ, secondary; entre 1 y 1,2 (el filo que se va gastando, Wear.kver_for_vb en
## core/taller/wear.gd), interpolación sin aviso (estimación); por debajo de 1 o por encima de 1,5, estimación y aviso.
## Un nombre desconocido avisa y vale 1.
static func _wear(wear: Variant, warnings: Array) -> Dictionary:
	if wear == null:
		return { "k": 1.0, "quality": "primary" }
	if typeof(wear) == TYPE_STRING or typeof(wear) == TYPE_STRING_NAME:
		var name := str(wear).to_lower()
		if WEAR_FACTORS.has(name):
			return { "k": WEAR_FACTORS[name], "quality": WEAR_QUALITY[name] }
		warnings.append("Estado del filo «%s» desconocido: se toma el filo nuevo (Kver = 1)." % str(wear))
		return { "k": 1.0, "quality": "estimate" }
	var k := float(wear)
	if k == 1.0 or (k >= 1.2 and k <= 1.5):
		return { "k": k, "quality": "secondary" }
	if k > 1.0 and k < 1.2:
		return { "k": k, "quality": "estimate" }
	warnings.append("Kver = %s, fuera del intervalo 1,2-1,5 del TZ." % Js.js_num_str(k))
	return { "k": k, "quality": "estimate" }


## Ksp del proceso p["process"] (sin distinguir mayúsculas); si no se conoce, avisa y usa el de default_key.
static func _process_factor(p: Dictionary, default_key: String, warnings: Array[String]) -> float:
	var name := str(p.get("process", default_key)).to_lower()
	if PROCESS_FACTORS.has(name):
		return PROCESS_FACTORS[name]
	warnings.append("Proceso «%s» desconocido: se usa «%s» (Ksp = %s)." % [
		str(p.get("process")), default_key, Js.js_num_str(PROCESS_FACTORS[default_key])])
	return PROCESS_FACTORS[default_key]


## Tabla de solo lectura con _model_entry() de todas las parejas material-herramienta de los catálogos. Se llama una
## vez, al inicializar la variable estática _model_table.
static func _build_model_table() -> Dictionary:
	var table := {}
	for w in WorkMaterials.ids():
		for t in ToolMaterials.ids():
			var e := _model_entry(w, t)
			e.make_read_only()
			table[w + "|" + t] = e
	table.make_read_only()
	return table


## Datos constantes de cutting_model para una pareja material-herramienta (lo que guarda _model_table).
static func _model_entry(work_id: String, tool_id: String) -> Dictionary:
	var work := WorkMaterials.get_material(work_id)
	var tool := ToolMaterials.get_tool(tool_id)
	if work.is_empty() or tool.is_empty():
		return { "ok": false, "reason": "Material o herramienta desconocidos." }
	if work["kc"] == null:
		return { "ok": false, "reason": work["kc_reason"] }
	var kc_data: Dictionary = work["kc"]
	var fcomp := WorkMaterials.force_components(work)
	var vr = tool["vc_range"].get(work["iso"])
	return {
		"ok": true, "kc11": kc_data["kc11"], "mc": kc_data["mc"], "kvc": tool["kvc"],
		"kf11": fcomp["kf11"], "mf": fcomp["mf"], "kp11": fcomp["kp11"], "mp": fcomp["mp"],
		"vc_lo": float(vr[0]) if vr != null else INF, "vc_hi": float(vr[1]) if vr != null else -INF,
		"quality": worst_quality(kc_data["quality"], tool["kvc_quality"]),
	}


## Fuerzas de avance y pasiva (N): Vector2(Ff, Fp) = A·(kf1.1/h^mf, kp1.1/h^mp).
static func _side_forces(c: Dictionary, area: float, h_eff: float) -> Vector2:
	return Vector2(
		area * float(c["kf11"]) * pow(h_eff, -float(c["mf"])),
		area * float(c["kp11"]) * pow(h_eff, -float(c["mp"])))


## Giro y velocidad de corte reales: de vc o de rpm, recortados por el tope de giro de la máquina. Sin velocidad
## (o con giro o vc ≤ 0) avisa y devuelve rpm = 0: quien llama no calcula fuerzas ni potencias.
static func _spindle(p: Dictionary, d: float, machine: Dictionary, warnings: Array[String]) -> Dictionary:
	var rpm := 0.0
	var vc := 0.0
	if p.get("rpm") != null:
		rpm = float(p["rpm"])
		vc = vc_from_rpm(rpm, d)
	elif p.get("vc") != null:
		vc = float(p["vc"])
		rpm = rpm_from_vc(vc, d)
	if rpm <= 0.0 or vc <= 0.0:
		warnings.append("Falta la velocidad: indica vc (m/min) o el giro (rpm), positivos.")
		return { "rpm": 0.0, "vc": 0.0, "limited": false }
	var limited := false
	var rpm_max := float(machine.get("rpm_max", INF))
	if rpm > rpm_max:
		var vc_max := vc_from_rpm(rpm_max, d)
		warnings.append("Tope de giro: la máquina llega a %s rpm y harían falta %s; vc baja de %s a %s m/min." % [
			Js.to_fixed(rpm_max, 0), Js.to_fixed(rpm, 0), Js.to_fixed(vc, 0), Js.to_fixed(vc_max, 0)])
		rpm = rpm_max
		vc = vc_max
		limited = true
	return { "rpm": rpm, "vc": vc, "limited": limited }


## Giro, velocidad y avances del fresado: { rpm, vc, fz, vf, limited }. Con fz y vf a la vez, n = vf/(z·fz); si
## no, n sale de vc o rpm y el avance que falte, del otro.
static func _mill_feed(p: Dictionary, dc: float, z: int, machine: Dictionary, warnings: Array[String]) -> Dictionary:
	var out := { "rpm": 0.0, "vc": 0.0, "fz": 0.0, "vf": 0.0, "limited": false }
	if p.get("fz_mm") != null and p.get("vf_mm_min") != null:
		var fz := float(p["fz_mm"])
		var vf := float(p["vf_mm_min"])
		var rpm := vf / (fz * z) if fz > 0.0 else 0.0
		var rpm_max := float(machine.get("rpm_max", INF))
		if rpm > rpm_max:
			warnings.append("Tope de giro: la máquina llega a %s rpm y harían falta %s; baja el avance de la mesa." % [
				Js.to_fixed(rpm_max, 0), Js.to_fixed(rpm, 0)])
			rpm = rpm_max
			vf = fz * z * rpm
			out["limited"] = true
		out["rpm"] = rpm
		out["vc"] = vc_from_rpm(rpm, dc)
		out["fz"] = fz
		out["vf"] = vf
		return out
	var sp := _spindle(p, dc, machine, warnings)
	var rpm: float = sp["rpm"]
	out["rpm"] = rpm
	out["vc"] = sp["vc"]
	out["limited"] = sp["limited"]
	if p.get("fz_mm") != null:
		out["fz"] = float(p["fz_mm"])
		out["vf"] = float(out["fz"]) * z * rpm
	elif p.get("vf_mm_min") != null and rpm > 0.0:
		out["vf"] = float(p["vf_mm_min"])
		out["fz"] = float(out["vf"]) / (z * rpm)
	return out


## Ángulos de contacto de la fresa (rad, desde la dirección de avance) y valores medio y máximo de sen φ, que
## multiplicados por fz·sen κ dan hm y hex. Centrada: |cos φ| ≤ ae/Dc (con Sandvik: hm = fz·sen κ·(ae/Dc)/
## asen(ae/Dc)). Lateral desde un borde: φ de 0 a acos(1 − 2·ae/Dc).
static func _engagement(ae: float, dc: float, centered: bool) -> Dictionary:
	var x := clampf(ae / dc, 1e-9, 1.0)
	var phi1 := 0.0
	var phi2 := 0.0
	if centered:
		phi1 = acos(x)
		phi2 = PI - phi1
	else:
		phi2 = acos(1.0 - 2.0 * x)
	var mean_sin := (cos(phi1) - cos(phi2)) / (phi2 - phi1)
	var max_sin := 1.0 if (phi1 <= PI / 2.0 and phi2 >= PI / 2.0) else maxf(sin(phi1), sin(phi2))
	return { "phi1": phi1, "phi2": phi2, "mean_sin": mean_sin, "max_sin": max_sin }


## kc del material con la herramienta, su banda de incertidumbre y su calidad. La banda recorre todas las familias
## de kc del material (la principal, las alternativas del TZ y la derivada de Sandvik) con las mismas correcciones.
## wear: { k, quality } de _wear().
static func _kc_result(work: Dictionary, tool: Dictionary, h: float, gamma: Variant, wear: Dictionary, ksp: float,
		warnings: Array[String]) -> Dictionary:
	var kc_data: Dictionary = work["kc"]
	var gamma0: float = kc_data["gamma0"]
	var g: float = gamma0 if gamma == null else float(gamma)
	if h < H_FLOOR:
		warnings.append("Espesor de viruta de %s mm: kc se calcula con %s mm (por debajo Kienzle se dispara)." % [
			Js.to_fixed(h, 3), Js.to_fixed(H_FLOOR, 2)])
	elif h < H_TABLE_MIN or h > H_TABLE_MAX:
		warnings.append("Espesor de viruta de %s mm, fuera de las tablas del TZ (%s-%s mm): kc extrapolado." % [
			Js.to_fixed(h, 3), Js.to_fixed(H_TABLE_MIN, 2), Js.to_fixed(H_TABLE_MAX, 1)])
	var corr := {
		"h_mm": maxf(h, H_FLOOR), "gamma_deg": g, "tool_factor": tool["kvc"], "wear_factor": wear["k"],
		"process_factor": ksp,
	}
	var main := {}
	var lo := INF
	var hi := -INF
	for fam in WorkMaterials.kc_families(work):  # la principal va primero
		var r := specific_cutting_force(_merge(corr, {
			"kc11": fam["kc11"], "mc": fam["mc"], "gamma0_deg": fam["gamma0"],
		}))
		if fam["main"]:
			main = r
		lo = minf(lo, r["kc"])
		hi = maxf(hi, r["kc"])
	var quality := worst_quality(kc_data["quality"], tool["kvc_quality"])
	quality = worst_quality(quality, wear["quality"])
	if absf(g - gamma0) > 1e-9 and not GAMMA0_KINDS.has(work["kind"]):
		quality = worst_quality(quality, "estimate")
	return { "kc": main["kc"], "band": [lo, hi], "parts": main, "quality": quality }


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


## Avisos de herramienta: no recomendada para el grupo ISO o vc fuera de su intervalo orientativo.
static func _tool_checks(tool: Dictionary, work: Dictionary, vc: float, warnings: Array[String]) -> void:
	var group: String = work["iso"]
	if not ToolMaterials.recommended(tool, group):
		warnings.append("%s no es un material de corte indicado para el grupo ISO %s (%s)." % [
			tool["name"], group, work["name"]])
		return
	var vr: Array = tool["vc_range"][group]
	if vc < float(vr[0]) or vc > float(vr[1]):
		warnings.append("vc = %s m/min, fuera del intervalo orientativo de %s en el grupo %s (%s-%s m/min)." % [
			Js.to_fixed(vc, 0), tool["name"], group, Js.to_fixed(float(vr[0]), 0), Js.to_fixed(float(vr[1]), 0)])


## Vida de Taylor (estimación) si la herramienta tiene datos para el grupo ISO del material.
static func _life(out: Dictionary, tool: Dictionary, work: Dictionary, vc: float, warnings: Array[String],
		sources: Array[String]) -> void:
	var tp := ToolMaterials.taylor_params(tool, work["iso"])
	if tp.is_empty() or work["kc"] == null:
		return
	out["life_min"] = taylor_life(vc, tp["n"], tp["C"])
	out["life_quality"] = tp["quality"]
	sources.append(tp["source"])
	if float(out["life_min"]) < 1.0:
		warnings.append("Vida estimada de menos de un minuto: la herramienta se quema enseguida a %s m/min." % [
			Js.to_fixed(vc, 0)])


## Sobrecarga: la potencia en el motor supera la de la máquina.
static func _overload(out: Dictionary, machine: Dictionary, warnings: Array[String]) -> void:
	if not machine.has("pmax_kw") or out["pmotor_kw"] == null:
		return
	var pmax := float(machine["pmax_kw"])
	if float(out["pmotor_kw"]) > pmax:
		out["overload"] = true
		warnings.append("Sobrecarga: el corte pide %s kW en el motor y la máquina da %s kW." % [
			Js.to_fixed(float(out["pmotor_kw"]), 1), Js.to_fixed(pmax, 1)])
