## Taller · afiladora: física del amolado a mano, en funciones puras (sin estado ni variables estáticas: se pueden
## llamar desde varios hilos a la vez). Detalle, validación y fuentes: docs/taller/afilado-simulador.md.
##
## Cadena de un paso de afilado (grind()):
##   1. Velocidad periférica de la muela: v = π·D·n/60 000 (m/s), con el giro que deja el motor bajo carga.
##   2. Fuerzas: el usuario pone la fuerza normal Fn (N); la tangencial es Ft = μ·Fn con la relación de fuerzas de
##      amolado μ = Ft/Fn = 0,25–0,40 en la mayoría de aceros (Biro, Hagan y Gustafson, SME 2019).
##   3. Potencia de amolado P = Ft·v (W). El par que pide la muela, Ft·D/2, frente al del motor decide si gira a su
##      velocidad, se frena o se cala (modelo de motor: estimación).
##   4. Calor que entra en la herramienta: ε·P, con el reparto ε de Malkin y Guo (2007): 60–85 % con muelas
##      convencionales y ≈20 % con CBN (Rowe et al. 2003 dan hasta el 50 % con CBN). En húmedo, ×0,42 mientras la
##      cara no pase de ≈130 °C (sharpening_heat.gd). Repartido en el área de contacto: q (W/m²) para edge_thermal.gd.
##   5. Metal arrancado Q = P/u (mm³/s), con la energía específica u del acero (Rowe et al. 2003: ≈90 J/mm³ en
##      acero templado de 60–62 HRC con poco espesor de viruta, hasta 200 con grano fino; ≈25 en condiciones
##      normales). Da la velocidad a la que avanza el bisel y la rebaba.
## Además: geometría del contacto del bisel, chispas y sonido para la escena, y la geometría de los errores de
## afilado de brocas y fresas (labios desiguales, incidencia, desplazamiento del dedo de apoyo).
## Unidades: N, m/s, W, mm, mm², mm³/s, J/mm³, W/m², °C, grados.
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const Sparks = preload("res://core/taller/sparks.gd")
const Radial = preload("res://core/taller/radial.gd")

const SRC_BIRO := "Biro, Hagan y Gustafson (Saint-Gobain Abrasives), «Understanding forces in creep-feed grinding», SME 2019: μ = Ft/Fn de 0,25 a 0,40 en la mayoría de aceros; potencia = Ft·Vs"
const SRC_ROWE := "Rowe, Morgan, Batako y Jin 2003, «Energy and temperature analysis in grinding», WIT Trans. Eng. Sci. 44: 25 J/mm³ típicos, hasta 200 J/mm³ con grano fino en materiales difíciles; fig. 2: acero de 60–62 HRC con muela A46 a 30 m/s, de ≈90 J/mm³ con el menor espesor de viruta a ≈62 con el mayor (efecto tamaño); reparto pieza–muela 0,9 con corindón y 0,5 con CBN"
const SRC_MALKIN := "Malkin y Guo 2007, «Thermal analysis of grinding», CIRP Annals 56/2: con muelas convencionales entra en la pieza el 60–85 % de la energía; con CBN, ≈20 %"
const SRC_TC9524_DRILL := "US Army TC 9-524, cap. 4: incidencia de 8–12°; labios de igual ángulo y longitud o el agujero sale mayor; «demasiada incidencia rompe el filo por falta de apoyo y deja poco metal para llevarse el calor»; «poca incidencia deja la broca casi sin filo y, al empujar más, se rompe»; ángulo de desprendimiento de 18–45° (30° el más común)"
const SRC_US4031672 := "Patente US 4031672 A (Moores y Walton, 1977): la tolerancia comercial de la diferencia de altura de los labios es de 0,003″ (0,076 mm) hasta 1/4″ de diámetro y 0,004″ (0,10 mm) de 1/4″ a 1/2″"
const SRC_US4561813 := "Patente US 4561813 A (Schneider, 1985): como el avance es constante y la velocidad de giro baja hacia el centro, el ángulo de ataque crece hacia el centro de la broca; la incidencia tiene que ser mayor que ese ángulo en cada punto del labio"
const SRC_MAZOFF := "Mazoff, «Drill point geometry» (Newman Tools): arista transversal a 110° ≈ 5° de incidencia (poca), 120° ≈ 8° (media) y 130° ≈ 11° (mucha); con 7° o menos el talón empieza a rozar; el exceso de incidencia da agujeros mayores y menos vida al filo"
const SRC_NPS := "Naval Postgraduate School, «Safety Gram: pedestal / bench grinder» (29 CFR 1910.215 y ANSI B7.1): no amolar con el costado de una muela recta salvo con presión muy ligera"

## Relación de fuerzas μ = Ft/Fn (la de sharpening.gd, NOMINAL_OPERATION).
const FORCE_RATIO := {
	"value": 0.325, "min": 0.25, "max": 0.40,
	"source": SRC_BIRO,
	"quality": "secondary",
}

## Fuerzas de la mano con nombre (N). No hay medida publicada de la fuerza al afilar a mano: son escalas para la
## interfaz, del orden de 0,5 a 4 kgf.
const HAND_FORCE := {
	"muy_ligera": { "value": 5.0, "source": "estimación: ≈0,5 kgf", "quality": "estimate" },
	"ligera": { "value": 10.0, "source": "estimación: ≈1 kgf (la operación nominal de sharpening.gd)", "quality": "estimate" },
	"moderada": { "value": 20.0, "source": "estimación: ≈2 kgf", "quality": "estimate" },
	"fuerte": { "value": 40.0, "source": "estimación: ≈4 kgf", "quality": "estimate" },
}

## Energía específica de amolado (J/mm³) según la dureza del acero.
const SPECIFIC_ENERGY := {
	"templado": {
		"value": 90.0, "min": 62.0, "max": 200.0, "hrc_from": 50.0,
		"source": SRC_ROWE + ". Al afilar a mano el espesor de viruta es aún menor: se toma el valor alto medido (90) y el techo de 200 del grano fino",
		"quality": "estimate",
	},
	"blando": {
		"value": 40.0, "min": 25.0, "max": 90.0,
		"source": SRC_ROWE + ". Acero sin templar (cuchillas de cortacésped): 25 J/mm³ típicos; con la poca presión de la mano, más (efecto tamaño)",
		"quality": "estimate",
	},
}

## Intervalo del reparto ε por abrasivo cuando la tabla de sharpening_heat.gd solo da el valor central.
const PARTITION_BAND := {
	"cbn": { "min": 0.15, "max": 0.50, "source": SRC_MALKIN + "; " + SRC_ROWE + " (el 0,5 de Rowe es la cota alta)", "quality": "secondary" },
	"diamante": { "min": 0.15, "max": 0.50, "source": "como el CBN (sin medida en acero: no se amola acero con diamante)", "quality": "estimate" },
}

## Modelo de motor (estimación): rendimiento, caída de giro a par nominal y par máximo relativo.
const MOTORS := {
	"induccion": {
		"efficiency": 0.5, "slip": 0.05, "breakdown": 2.0,
		"source": "estimación: rendimiento de ≈50 % de un motor monofásico pequeño con condensador (los fabricantes solo dan la potencia de entrada); deslizamiento del 3–5 % a plena carga (catálogos IEC 60034, machine_sound.gd); par máximo ≈2 veces el nominal. Einhell: si la muela se bloquea, retirar la pieza y empujar con menos fuerza",
		"quality": "estimate",
	},
	"universal": {
		"efficiency": 0.55, "slip": 0.30, "breakdown": 2.5,
		"source": "estimación: motor universal (radial y afiladoras pequeñas), caída del 30 % a plena carga (machine_sound.gd, Chapman 2012)",
		"quality": "estimate",
	},
	"universal_constante": {
		"efficiency": 0.55, "slip": 0.0, "breakdown": 1.6,
		"source": "estimación: con electrónica de velocidad constante (Einhell TE-AG 125 CE: «rendimiento constante también con carga») el giro no cae hasta su límite; después, como un motor universal",
		"quality": "estimate",
	},
}

## Chispas: sin chispas por debajo de esta velocidad o en húmedo (a 1–2 m/s el grano no lleva la viruta a la
## incandescencia y el agua la apaga). ESTIMACIÓN; el ensayo de chispas pide ≥ 25 m/s (sparks.gd, TC 9-237).
const SPARK_MIN_MS := 5.0


## Velocidad periférica (m/s) de una muela de d_mm a rpm (la de sharpening.gd).
static func peripheral_speed(d_mm: float, rpm: float) -> float:
	return Sharpening.peripheral_speed(d_mm, rpm)


## Contacto del bisel de un cuchillo con la muela. p: per_side_deg (ángulo por lado), thickness_mm (espesor tras el
## bisel), contact_len_mm (largo del filo apoyado en la muela, por ejemplo el ancho de la muela; 10 mm por defecto),
## wheel_diameter_mm (para el vaciado de la periferia), mode: "periferia" | "cara" | "lenta_humeda".
## Devuelve { face_width_mm (ancho de la cara del bisel, (t/2)/sen β), bevel_x_mm (ancho medido por el plano medio),
## contact_len_mm, area_mm2, hollow_um (flecha del vaciado cóncavo que deja la periferia), source, quality }.
static func knife_contact(p: Dictionary) -> Dictionary:
	var beta := clampf(Heat.input_num(p, "per_side_deg", 17.5), 1.0, 60.0)
	var t := maxf(Heat.input_num(p, "thickness_mm", 0.6), 0.01)
	return edge_contact({
		"side_a_deg": beta, "side_b_deg": beta, "shoulder_mm": t,
		"contact_len_mm": p.get("contact_len_mm"), "wheel_diameter_mm": p.get("wheel_diameter_mm"), "mode": p.get("mode", "periferia"),
	})


## Contacto de una cuña cualquiera (simétrica o de un solo bisel): side_a_deg (cara en la muela), side_b_deg,
## shoulder_mm, contact_len_mm, wheel_diameter_mm, mode. Como knife_contact.
static func edge_contact(p: Dictionary) -> Dictionary:
	var a := clampf(Heat.input_num(p, "side_a_deg", 17.5), 1.0, 60.0)
	var b := clampf(Heat.input_num(p, "side_b_deg", a), 0.0, 60.0)
	var t := maxf(Heat.input_num(p, "shoulder_mm", 0.6), 0.01)
	var x := t / (tan(deg_to_rad(a)) + tan(deg_to_rad(b)))
	var face := x / cos(deg_to_rad(a))
	var length := maxf(Heat.input_num(p, "contact_len_mm", 10.0), 0.1)
	var d := Heat.input_num(p, "wheel_diameter_mm", 0.0)
	var mode := str(p.get("mode", "periferia"))
	var hollow := 0.0
	if mode == "periferia" and d > 0.0:
		var r := d / 2.0
		var half := minf(face / 2.0, r)
		hollow = (r - sqrt(r * r - half * half)) * 1000.0
	return {
		"face_width_mm": face,
		"bevel_x_mm": x,
		"contact_len_mm": length,
		"area_mm2": face * length,
		"hollow_um": hollow,
		"mode": mode,
		"source": "Geometría de la cuña: la cara del bisel mide t/(tan a + tan b)/cos a (con a = b, (t/2)/sen β, como sharpening.gd); flecha del vaciado r − √(r² − (w/2)²)",
		"quality": "primary",
	}


## Relación de fuerzas y fuerza tangencial: { fn_n, mu, ft_n, ft_min_n, ft_max_n, source, quality }.
static func forces(fn_n: float, mu: float = -1.0) -> Dictionary:
	var fn := maxf(fn_n, 0.0) if is_finite(fn_n) else 0.0
	var m: float = mu if mu > 0.0 and is_finite(mu) else FORCE_RATIO["value"]
	return {
		"fn_n": fn,
		"mu": m,
		"ft_n": m * fn,
		"ft_min_n": float(FORCE_RATIO["min"]) * fn,
		"ft_max_n": float(FORCE_RATIO["max"]) * fn,
		"source": FORCE_RATIO["source"],
		"quality": FORCE_RATIO["quality"],
	}


## Reparto del calor: parte de la potencia de amolado que entra en la herramienta.
## abrasive_id: el de la muela ("" = desconocido: se toma el corindón); wet y surface_c: en húmedo el agua enfría
## mientras la cara del contacto no pasa de la ebullición en película (≈130 °C).
## Devuelve { value, min, max, dry, coolant_effective, abrasive_id, source, quality }.
static func partition(abrasive_id: String, wet: bool = false, surface_c: float = Heat.AMBIENT_C) -> Dictionary:
	var ab := abrasive_id if Heat.ENERGY_PARTITION.has(abrasive_id) else "al2o3"
	var e: Dictionary = Heat.ENERGY_PARTITION[ab]
	var val: float = e["value"]
	var lo: float = e.get("min", val)
	var hi: float = e.get("max", val)
	var src := str(e["source"])
	var quality := str(e["quality"])
	if PARTITION_BAND.has(ab):
		var band: Dictionary = PARTITION_BAND[ab]
		lo = band["min"]
		hi = band["max"]
		src += "; " + str(band["source"])
	var cooled := wet and surface_c < Heat.BURNOUT_WATER_C
	var f: float = Heat.WET_FACTOR["value"] if cooled else 1.0
	if cooled:
		src += "; " + str(Heat.WET_FACTOR["source"])
		quality = "estimate"
	return {
		"value": val * f,
		"min": lo * f,
		"max": hi * f,
		"dry": val,
		"coolant_effective": cooled,
		"abrasive_id": ab,
		"source": src,
		"quality": quality,
	}


## Energía específica de amolado (J/mm³) para un acero de STEELS (o con la dureza hrc que se pase): templado a partir
## de 50 HRC. { value, min, max, regime, source, quality }.
static func specific_energy(steel_id: String, hrc: float = -1.0) -> Dictionary:
	var h := hrc
	if h <= 0.0 and Heat.STEELS.has(steel_id):
		h = float(Heat.STEELS[steel_id]["hrc"]["value"])
	var regime := "templado" if h >= float(SPECIFIC_ENERGY["templado"]["hrc_from"]) or (h <= 0.0 and Sharpening.TOOL_MATERIALS.has(steel_id)) else "blando"
	var e: Dictionary = SPECIFIC_ENERGY[regime]
	return { "value": e["value"], "min": e["min"], "max": e["max"], "regime": regime, "source": e["source"], "quality": e["quality"] }


## Motor bajo carga: con el par que pide la muela (N·m) frente al nominal (η·P de entrada a las rpm nominales).
## { rpm, load (par / par nominal), overloaded, stalled, torque_nm, rated_torque_nm, output_w, source, quality }.
static func motor_state(motor: Dictionary, rpm_no_load: float, torque_nm: float) -> Dictionary:
	var kind := str(motor.get("type", "induccion"))
	var m: Dictionary = MOTORS.get(kind, MOTORS["induccion"])
	var p_in := float(motor["input_w"]["value"])
	var p_out := float(m["efficiency"]) * p_in
	var slip: float = m["slip"]
	var n_rated := rpm_no_load * (1.0 - maxf(slip, 0.05))
	var rated := p_out / maxf(TAU * n_rated / 60.0, 1e-9)
	var load := torque_nm / maxf(rated, 1e-12)
	var bd: float = m["breakdown"]
	var n := rpm_no_load
	var stalled := load > bd
	if stalled:
		n = 0.0
	elif kind == "universal_constante":
		n = rpm_no_load * (1.0 - 0.3 * maxf(load - 1.0, 0.0))
	else:
		n = rpm_no_load * (1.0 - slip * load)
	return {
		"rpm": maxf(n, 0.0),
		"load": load,
		"overloaded": load > 1.0,
		"stalled": stalled,
		"torque_nm": torque_nm,
		"rated_torque_nm": rated,
		"output_w": p_out,
		"source": m["source"],
		"quality": m["quality"],
	}


## Un paso de afilado en una máquina del catálogo. p = {
##   machine_id, wheel (id o índice; 0 por defecto), rpm (solo en las de velocidad regulable; si no, la de serie),
##   diameter_mm (muela gastada), force_n (fuerza normal), contact_area_mm2 (del bisel: knife_contact), wet (por
##   defecto, el de la muela), surface_c (cara del contacto ahora, de edge_thermal: decide si el agua enfría),
##   steel_id, hrc, mu, mode ("periferia" | "cara") }.
## Devuelve { vs_ms, rpm, rpm_no_load, load, overloaded, stalled, ft_n, power_w, power_min_w, power_max_w,
##   partition, heat_w, heat_flux_w_m2, heat_flux_min_w_m2, heat_flux_max_w_m2, specific_energy_j_mm3,
##   removal_mm3_s, removal_min_mm3_s, removal_max_mm3_s, over_speed, max_speed_ms, abrasive_id, wet, sparks,
##   sound, warnings [{ code, message, source }], sources, quality }.
static func grind(p: Dictionary) -> Dictionary:
	var warnings: Array = []
	var mid := str(p.get("machine_id", ""))
	var m: Dictionary = Machines.MACHINES.get(mid, {})
	if m.is_empty():
		return _empty(mid, "Máquina «%s» desconocida." % mid)
	var wref: Variant = p.get("wheel", 0)
	var w := Machines.wheel(mid, wref)
	if w.is_empty():
		w = Machines.wheel(mid, 0)
		_warn(warnings, "muela", "Muela «%s» desconocida: se usa la primera de la máquina." % str(wref), str(m["source"]))
	var motor: Dictionary = m["motor"]
	var rpm_info: Dictionary = motor["rpm_no_load"]
	# Giro sin carga de la muela: el de serie, o el pedido si la máquina es regulable
	var n0: float = w["rpm"]
	var req_rpm := Heat.input_num(p, "rpm", -1.0)
	if req_rpm > 0.0:
		if rpm_info.has("steps"):
			# rueda de velocidades: la posición más cercana a lo pedido
			var steps: Array = rpm_info["steps"]
			var best: float = steps[0]
			for s in steps:
				if absf(float(s) - req_rpm) < absf(best - req_rpm):
					best = float(s)
			n0 = best
		elif absf(req_rpm - n0) > 1e-9:
			_warn(warnings, "giro_fijo", "%s gira a %s rpm: su velocidad no se regula." % [m["name"], _fmt(n0, 0)], str(rpm_info["source"]))
	# Diámetro (muela gastada)
	var d: float = w["diameter_mm"]
	var req_d := Heat.input_num(p, "diameter_mm", -1.0)
	if req_d > 0.0:
		var dmin: float = w["diameter_min_mm"] if w.get("diameter_min_mm") != null else 0.0
		if req_d > d + 1e-9:
			_warn(warnings, "diametro", "La muela de serie mide %s mm: no se monta una mayor." % _fmt(d, 0), str(w["source"]))
		else:
			d = req_d
			if dmin > 0.0 and d < dmin:
				_warn(warnings, "muela_gastada", "Muela gastada por debajo de su mínimo (%s mm): cámbiala." % _fmt(dmin, 0), str(w["source"]))
	# Sobrevelocidad (solo si se fuerza un giro mayor que el marcado en la muela o el disco)
	var over := false
	var max_v: Variant = null
	if w.get("max_rpm") != null:
		max_v = peripheral_speed(float(w["diameter_mm"]), float(w["max_rpm"]))
		if n0 > float(w["max_rpm"]):
			over = true
			_warn(warnings, "exceso_velocidad", "¡Peligro! La muela está marcada para %s rpm como máximo y gira a %s: puede reventar." % [_fmt(float(w["max_rpm"]), 0), _fmt(n0, 0)], str(w["source"]))
	# Fuerzas, motor y velocidad bajo carga
	var fn := maxf(Heat.input_num(p, "force_n", float(HAND_FORCE["ligera"]["value"])), 0.0)
	var fr := forces(fn, Heat.input_num(p, "mu", -1.0))
	var torque := float(fr["ft_n"]) * d / 2000.0
	var ms := motor_state(motor, n0, torque)
	var n := float(ms["rpm"])
	if bool(ms["stalled"]):
		_warn(warnings, "se_cala", "La muela se para: el motor no da el par que pide esa fuerza. Retira la pieza, espera a que recupere el giro y apoya con menos fuerza (manual de Einhell).", str(ms["source"]))
	elif bool(ms["overloaded"]):
		_warn(warnings, "se_frena", "El motor va sobrecargado y la muela se frena: menos fuerza.", str(ms["source"]))
	var vs := peripheral_speed(d, n)
	var ft := float(fr["ft_n"]) if n > 0.0 else 0.0
	var power := ft * vs
	var p_lo := float(fr["ft_min_n"]) * vs if n > 0.0 else 0.0
	var p_hi := float(fr["ft_max_n"]) * vs if n > 0.0 else 0.0
	# Abrasivo contra el material
	var steel := str(p.get("steel_id", ""))
	var ab := str(w["abrasive_id"])
	if steel != "" and not bool(w["honing"]) and not Machines.abrasive_suits(ab, steel):
		if ab == "diamante":
			_warn(warnings, "diamante_acero", "Nunca diamante para amolar acero: se oxida por encima de 600 °C y reacciona con el hierro (Brazda 2006); la muela SDC es para metal duro.", Sharpening.SRC_DIAMOND_FE)
		elif ab == "sic":
			_warn(warnings, "sic_acero", "El carburo de silicio es para fundición, metal duro y no férricos (Norton 37C/39C), no para acero.", Sharpening.SRC_NORTON)
		else:
			_warn(warnings, "abrasivo_metal_duro", "El metal duro se amola con diamante (o SiC verde), no con esta muela.", Sharpening.SRC_HAEFELI)
	# Calor
	var wet: bool = Heat.input_flag(p, "wet", bool(w["wet"]))
	var surface := Heat.input_num(p, "surface_c", Heat.AMBIENT_C)
	var part := partition(ab, wet, surface)
	if wet and not bool(part["coolant_effective"]):
		_warn(warnings, "agua_hierve", "La cara del filo pasa de ≈130 °C: el agua hierve en película y ya no enfría (Malkin y Guo 2007).", str(Heat.THRESHOLDS["burnout_water_c"]["source"]))
	var area := maxf(Heat.input_num(p, "contact_area_mm2", 10.0), 1e-3) * 1e-6
	var heat_w := float(part["value"]) * power
	var q := heat_w / area
	var q_lo := float(part["min"]) * p_lo / area
	var q_hi := float(part["max"]) * p_hi / area
	# Metal arrancado
	var u := specific_energy(steel, Heat.input_num(p, "hrc", -1.0))
	var q_mm3 := power / float(u["value"]) if not bool(w["honing"]) else 0.0
	var q_mm3_lo := p_lo / float(u["max"]) if not bool(w["honing"]) else 0.0
	var q_mm3_hi := p_hi / float(u["min"]) if not bool(w["honing"]) else 0.0
	# Costado de la muela
	var mode := str(p.get("mode", "periferia"))
	if mode == "cara" and str(m["kind"]) in ["banco", "banco_lenta", "combinada"] and not wet:
		_warn(warnings, "costado_muela", "No amoles con el costado de una muela recta salvo con presión muy ligera (ANSI B7.1).", SRC_NPS)
	var sources: Array[String] = [str(m["source"]), str(fr["source"]), str(part["source"]), str(u["source"]), str(ms["source"])]
	return {
		"machine_id": mid,
		"wheel_id": str(w["id"]),
		"vs_ms": vs,
		"rpm": n,
		"rpm_no_load": n0,
		"diameter_mm": d,
		"load": ms["load"],
		"overloaded": ms["overloaded"],
		"stalled": ms["stalled"],
		"motor_output_w": ms["output_w"],
		"fn_n": fn,
		"ft_n": ft,
		"mu": fr["mu"],
		"power_w": power,
		"power_min_w": p_lo,
		"power_max_w": p_hi,
		"partition": part["value"],
		"partition_min": part["min"],
		"partition_max": part["max"],
		"coolant_effective": part["coolant_effective"],
		"heat_w": heat_w,
		"heat_flux_w_m2": q,
		"heat_flux_min_w_m2": q_lo,
		"heat_flux_max_w_m2": q_hi,
		"specific_energy_j_mm3": u["value"],
		"removal_mm3_s": q_mm3,
		"removal_min_mm3_s": q_mm3_lo,
		"removal_max_mm3_s": q_mm3_hi,
		"over_speed": over,
		"max_speed_ms": max_v,
		"abrasive_id": ab,
		"wet": wet,
		"honing": bool(w["honing"]),
		"sparks": spark_input(steel, q_mm3, vs, wet),
		"sound": sound_input(mid, n0 if n > 0.0 else 0.0, power, wet),
		"warnings": warnings,
		"sources": sources,
		"quality": "estimate",
	}


## Velocidad con la que retrocede la cara del bisel (µm/s): el metal arrancado Q repartido en el área de contacto.
static func bevel_recession_um_s(removal_mm3_s: float, area_mm2: float) -> float:
	if not (area_mm2 > 0.0):
		return 0.0
	return maxf(removal_mm3_s, 0.0) / area_mm2 * 1000.0


## Entrada para core/taller/sparks.gd (resolve_stream / configure): { material_id, vs_ms, sparks { rate } }.
## rate: chispas visibles por segundo, con la misma escala que la radial (100 por mm³ con un chorro de tamaño 1,
## radial.gd) por el tamaño del chorro del acero en el ensayo de chispas. Sin chispas en húmedo o por debajo de
## SPARK_MIN_MS. La longitud y el color los pone sparks.gd con su tabla (según vs).
static func spark_input(steel_id: String, removal_mm3_s: float, vs_ms: float, wet: bool) -> Dictionary:
	var fam := Sparks.signature_for(steel_id)
	var rate := 0.0
	if not wet and vs_ms >= SPARK_MIN_MS:
		rate = Radial.SPARKS_PER_MM3 * float(fam["volume"]) * maxf(removal_mm3_s, 0.0)
	return {
		"material_id": steel_id,
		"vs_ms": vs_ms,
		"sparks": { "rate": rate },
		"family": Sparks.family_of(steel_id),
		"quality": "estimate",
		"source": "Escala de chispas visibles de radial.gd (estimación) y firma del ensayo de chispas de sparks.gd (TC 9-237, tabla 7-5)",
	}


## Entrada de sonido de máquina (CONTRATOS.md) para machine_sound.gd: la esmeriladora y las afiladoras suenan como
## «sharpener»; la amoladora, como «grinder» con su disco. rpm es el giro SIN carga de la muela (0 si se ha calado):
## machine_sound.gd le aplica la caída con pc_kw/pmax_kw y speed_droop, que son los del modelo de motor de aquí, así
## que el giro que suena es el mismo que da grind(). En las lentas con reductora es el giro de la muela, no el del
## motor (que no se publica).
static func sound_input(machine_id: String, rpm: float, power_w: float, wet: bool) -> Dictionary:
	var m: Dictionary = Machines.MACHINES.get(machine_id, {})
	if m.is_empty():
		return {}
	var kind := str(m["kind"])
	var motor: Dictionary = m["motor"]
	var mm: Dictionary = MOTORS.get(str(motor["type"]), MOTORS["induccion"])
	var w0: Dictionary = m["wheels"][0]
	var out := {
		"process": "grinder" if kind == "amoladora" else "sharpener",
		"rpm": rpm,
		"teeth": 0,
		"jaws": 0,
		"pc_kw": maxf(power_w, 0.0) / 1000.0,
		"pmax_kw": float(mm["efficiency"]) * float(motor["input_w"]["value"]) / 1000.0,
		"work_kind": "acero",
		"chatter": null,
		"coolant": wet,
		"tool_pos": Vector3.ZERO,
		"mains_hz": m["mains_hz"],
		"speed_droop": mm["slip"],
		"diameter_mm": w0["diameter_mm"],
	}
	if w0.has("disc_id"):
		out["disc_id"] = w0["disc_id"]
	return out


# ─────────────────────────────── Brocas ───────────────────────────────

## Tolerancia comercial de la diferencia de altura de los labios (mm) para un diámetro: 0,076 mm hasta 1/4″ y
## 0,10 mm hasta 1/2″ (US 4031672); null por encima (sin dato).
static func lip_height_tolerance_mm(diameter_mm: float) -> Variant:
	if diameter_mm <= 6.35:
		return 0.0762
	if diameter_mm <= 12.7:
		return 0.1016
	return null


## Punta descentrada por labios desiguales (geometría del cono): con la diferencia de altura de los labios Δh (en el
## eje) o de longitud ΔL (a lo largo del labio) y el semiángulo de punta p, la punta se desplaza e = Δh·tan p / 2 =
## ΔL·sen p / 2 del eje. Si la broca gira sobre su punta, el agujero sale D + 2e (cota geométrica: la guía de las
## faldillas y la rigidez lo reducen). p = { diameter_mm, point_deg, lip_height_diff_mm | lip_length_diff_mm }.
static func drill_point_offset(p: Dictionary) -> Dictionary:
	var d := maxf(Heat.input_num(p, "diameter_mm", 8.0), 0.1)
	var half := deg_to_rad(clampf(Heat.input_num(p, "point_deg", 118.0), 60.0, 170.0) / 2.0)
	var dh := absf(Heat.input_num(p, "lip_height_diff_mm", NAN))
	var dl := absf(Heat.input_num(p, "lip_length_diff_mm", NAN))
	var e := 0.0
	if not is_nan(dh):
		e = dh * tan(half) / 2.0
		dl = 2.0 * e / sin(half)
	elif not is_nan(dl):
		e = dl * sin(half) / 2.0
		dh = 2.0 * e / tan(half)
	else:
		dh = 0.0
		dl = 0.0
	var tol: Variant = lip_height_tolerance_mm(d)
	return {
		"offset_mm": e,
		"oversize_mm": 2.0 * e,
		"hole_mm": d + 2.0 * e,
		"lip_height_diff_mm": dh,
		"lip_length_diff_mm": dl,
		"tolerance_mm": tol,
		"within_tolerance": (dh <= float(tol) + 1e-12) if tol != null else null,
		"source": "Geometría del cono de la punta; " + SRC_TC9524_DRILL + "; " + SRC_US4031672,
		"quality": "primary",
	}


## Ángulo de la hélice que describe un punto del labio a r_mm del eje con un avance de feed_mm_rev (grados):
## atan(f/(2π·r)). El flanco no roza si la incidencia es mayor (US 4561813).
static func feed_helix_deg(feed_mm_rev: float, r_mm: float) -> float:
	if not (r_mm > 0.0):
		return 90.0
	return rad_to_deg(atan(maxf(feed_mm_rev, 0.0) / (TAU * r_mm)))


## Incidencia efectiva (grados) en un punto a r_mm del eje: la afilada menos la hélice del avance.
static func effective_clearance(clearance_deg: float, feed_mm_rev: float, r_mm: float) -> float:
	return clearance_deg - feed_helix_deg(feed_mm_rev, r_mm)


## Ángulo de la arista transversal que se ve con una incidencia dada (Mazoff: 110° ≈ 5°, 120° ≈ 8°, 130° ≈ 11°;
## recta que pasa por los tres puntos). Sirve para comprobar la incidencia mirando la punta.
static func chisel_angle_deg(clearance_deg: float) -> float:
	return 110.0 + (clearance_deg - 5.0) * 10.0 / 3.0


## La incidencia que corresponde a un ángulo de arista transversal (inversa de chisel_angle_deg).
static func clearance_from_chisel_deg(chisel_deg: float) -> float:
	return 5.0 + (chisel_deg - 110.0) * 3.0 / 10.0


## Ángulo de la cuña del labio (grados): 90° − incidencia − desprendimiento (el de la hélice en la periferia).
static func lip_wedge_deg(clearance_deg: float, rake_deg: float = 30.0) -> float:
	return 90.0 - clearance_deg - rake_deg


## Comprueba el afilado de una broca. p = { diameter_mm, point_deg, clearance_deg, lip_height_diff_mm, feed_mm_rev,
## work_material, rake_deg }. Compara con sharpening.gd (drill_angles) y con las reglas de TC 9-524.
## Devuelve { findings: [{ code, severity: "ok" | "aviso" | "mal", message, source }], recommended, offset,
## effective_clearance_deg (en la periferia y a 0,1·D del eje), chisel_deg, wedge_deg, ok }.
static func drill_check(p: Dictionary) -> Dictionary:
	var d := maxf(Heat.input_num(p, "diameter_mm", 8.0), 0.1)
	var rec := Sharpening.drill_angles({ "work_material": str(p.get("work_material", "acero")), "diameter_mm": d })
	var point := Heat.input_num(p, "point_deg", float(rec["point"]["value"]))
	var clearance := Heat.input_num(p, "clearance_deg", float(rec["clearance"]["value"]))
	var feed := maxf(Heat.input_num(p, "feed_mm_rev", 0.1), 0.0)
	var rake := Heat.input_num(p, "rake_deg", 30.0)
	var offset := drill_point_offset({ "diameter_mm": d, "point_deg": point, "lip_height_diff_mm": Heat.input_num(p, "lip_height_diff_mm", 0.0) })
	var findings: Array = []
	var pmin: float = rec["point"]["min"]
	var pmax: float = rec["point"]["max"]
	if point > pmax + 5.0:
		findings.append({ "code": "punta_plana", "severity": "aviso", "message": "Punta de %s°, más plana que los %s° recomendados: centra peor." % [_fmt(point, 0), _fmt(pmax, 0)], "source": SRC_TC9524_DRILL })
	elif point < pmin - 5.0:
		findings.append({ "code": "punta_aguda", "severity": "aviso", "message": "Punta de %s°, más aguda que los %s° recomendados: pide más fuerza y corta despacio." % [_fmt(point, 0), _fmt(pmin, 0)], "source": SRC_TC9524_DRILL })
	var eff_out := effective_clearance(clearance, feed, d / 2.0)
	var eff_in := effective_clearance(clearance, feed, 0.1 * d)
	if clearance < 7.0:
		findings.append({ "code": "poca_incidencia", "severity": "mal", "message": "Incidencia de %s°: el talón roza el fondo del agujero, la broca apenas corta y, si se empuja más, se rompe." % _fmt(clearance, 1), "source": SRC_TC9524_DRILL + "; " + SRC_MAZOFF + "; " + SRC_US4561813 })
	elif eff_in <= 0.0:
		findings.append({ "code": "poca_incidencia", "severity": "mal", "message": "Con %s mm/v de avance, junto al centro la incidencia efectiva es de %s°: el talón roza. Da más incidencia hacia el centro o baja el avance." % [_fmt(feed, 2), _fmt(eff_in, 1)], "source": SRC_US4561813 + "; " + SRC_TC9524_DRILL })
	elif clearance > 15.0:
		findings.append({ "code": "mucha_incidencia", "severity": "mal", "message": "Incidencia de %s°: al labio le falta apoyo y se mella, y le queda poco metal para llevarse el calor." % _fmt(clearance, 1), "source": SRC_TC9524_DRILL + "; " + SRC_MAZOFF })
	elif clearance < float(rec["clearance"]["min"]) or clearance > float(rec["clearance"]["max"]):
		findings.append({ "code": "incidencia_fuera", "severity": "aviso", "message": "Incidencia de %s°, fuera de los 8–12° de TC 9-524." % _fmt(clearance, 1), "source": SRC_TC9524_DRILL })
	var tol: Variant = offset["tolerance_mm"]
	var dh: float = offset["lip_height_diff_mm"]
	if dh > 0.0 and (tol == null or dh > float(tol)):
		findings.append({ "code": "labios_desiguales", "severity": "mal", "message": "Labios desiguales (%s mm de diferencia de altura): la punta se descentra %s mm, el agujero sale hasta %s mm mayor y la broca se gasta antes." % [_fmt(dh, 2), _fmt(float(offset["offset_mm"]), 3), _fmt(float(offset["oversize_mm"]), 2)], "source": SRC_TC9524_DRILL + "; " + SRC_US4031672 })
	if findings.is_empty():
		findings.append({ "code": "bien", "severity": "ok", "message": "Punta, incidencia y labios dentro de lo recomendado.", "source": SRC_TC9524_DRILL })
	var ok := true
	for f in findings:
		if str(f["severity"]) == "mal":
			ok = false
	return {
		"findings": findings,
		"recommended": rec,
		"offset": offset,
		"effective_clearance_deg": { "outer": eff_out, "inner": eff_in, "feed_mm_rev": feed },
		"chisel_deg": chisel_angle_deg(clearance),
		"wedge_deg": lip_wedge_deg(clearance, rake),
		"ok": ok,
	}


# ─────────────────────────────── Fresas ───────────────────────────────

## Comprueba el afilado de una fresa de mango en una afiladora universal. p = { diameter_mm, work_material,
## primary_deg, secondary_deg, wheel: "copa" | "recta", wheel_diameter_mm }. Compara con sharpening.gd (mill_angles)
## y da el desplazamiento del dedo de apoyo para la incidencia afilada (TC 9-524: D es el de la fresa con muela de
## copa y el de la muela con muela recta).
static func mill_check(p: Dictionary) -> Dictionary:
	var d := maxf(Heat.input_num(p, "diameter_mm", 10.0), 0.1)
	var rec := Sharpening.mill_angles({ "work_material": str(p.get("work_material", "acero")), "diameter_mm": d })
	var a1 := Heat.input_num(p, "primary_deg", float(rec["primary_clearance"]["value"]))
	var a2 := Heat.input_num(p, "secondary_deg", float(rec["secondary_clearance"]["value"]))
	var wheel_kind := str(p.get("wheel", "copa"))
	var d_ref := d if wheel_kind == "copa" else maxf(Heat.input_num(p, "wheel_diameter_mm", 100.0), 1.0)
	var findings: Array = []
	var r1: Dictionary = rec["primary_clearance"]
	if a1 < float(r1["min"]) - 1.0:
		findings.append({ "code": "poca_incidencia", "severity": "mal", "message": "Incidencia primaria de %s°: el filo roza, se calienta y no corta limpio." % _fmt(a1, 1), "source": Sharpening.SRC_TC9524_MILL + "; " + Sharpening.SRC_NACHI_EM })
	elif a1 > float(r1["max"]) + 2.0:
		findings.append({ "code": "mucha_incidencia", "severity": "mal", "message": "Incidencia primaria de %s°: el filo queda débil y se mella." % _fmt(a1, 1), "source": Sharpening.SRC_TC9524_MILL + "; " + Sharpening.SRC_NACHI_EM })
	if a2 <= a1:
		findings.append({ "code": "secundaria", "severity": "mal", "message": "La incidencia secundaria (%s°) tiene que ser mayor que la primaria (%s°) o el talón roza." % [_fmt(a2, 1), _fmt(a1, 1)], "source": Sharpening.SRC_NACHI_EM })
	if findings.is_empty():
		findings.append({ "code": "bien", "severity": "ok", "message": "Incidencias dentro de lo recomendado.", "source": Sharpening.SRC_NACHI_EM })
	return {
		"findings": findings,
		"recommended": rec,
		"offset_mm": Sharpening.cutter_grinder_offset(a1, d_ref),
		"offset_exact_mm": Sharpening.cutter_grinder_offset_exact(a1, d_ref),
		"offset_reference_mm": d_ref,
		"wheel": wheel_kind,
	}


# ─────────────────────────────── Internos ───────────────────────────────

static func _warn(list: Array, code: String, message: String, source: String) -> void:
	list.append({ "code": code, "message": message, "source": source })


static func _empty(mid: String, message: String) -> Dictionary:
	return {
		"machine_id": mid, "wheel_id": "", "vs_ms": 0.0, "rpm": 0.0, "rpm_no_load": 0.0, "diameter_mm": 0.0,
		"load": 0.0, "overloaded": false, "stalled": false, "motor_output_w": 0.0, "fn_n": 0.0, "ft_n": 0.0,
		"mu": FORCE_RATIO["value"], "power_w": 0.0, "power_min_w": 0.0, "power_max_w": 0.0, "partition": 0.0,
		"partition_min": 0.0, "partition_max": 0.0, "coolant_effective": false, "heat_w": 0.0,
		"heat_flux_w_m2": 0.0, "heat_flux_min_w_m2": 0.0, "heat_flux_max_w_m2": 0.0, "specific_energy_j_mm3": 0.0,
		"removal_mm3_s": 0.0, "removal_min_mm3_s": 0.0, "removal_max_mm3_s": 0.0, "over_speed": false,
		"max_speed_ms": null, "abrasive_id": "", "wet": false, "honing": false, "sparks": spark_input("", 0.0, 0.0, false), "sound": {},
		"warnings": [{ "code": "sin_datos", "message": message, "source": "" }], "sources": [], "quality": "estimate",
	}


## Número con coma decimal y sin ceros de sobra (toFixed de JavaScript, como sharpening.gd).
static func _fmt(x: float, decimals: int) -> String:
	var s := Js.to_fixed(x, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")
