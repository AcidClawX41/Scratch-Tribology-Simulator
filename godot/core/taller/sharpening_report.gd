## Taller · afiladora: la nota y los consejos de un ensayo de afilado (sharpening_sim.gd). Funciones puras, sin estado:
## reciben los hechos del ensayo (números del core) y devuelven textos en español con su fuente.
##
## La nota (0–10) es una RÚBRICA PEDAGÓGICA, no física: cuánto pesa cada fallo (RUBRIC). Lo que decide si hay fallo sí
## sale de la física y los datos con fuente: el filo llega o no al vértice (sharpening_bevel.gd), la pérdida de
## dureza y el quemado (edge_thermal.gd), el ángulo recomendado (sharpening.gd), el abrasivo y la seguridad
## (grinding.gd, sharpening_machines.gd), la revisión de brocas y fresas (grinding.gd).
## Detalle en docs/taller/afilado-simulador.md → «Integración, oleada 2».
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const Sharpening = preload("res://core/taller/sharpening.gd")
const Heat = preload("res://core/taller/sharpening_heat.gd")
const Machines = preload("res://core/taller/sharpening_machines.gd")
const G = preload("res://core/taller/grinding.gd")

const SRC_TOR_WAY := "Tormek, «The Tormek way of sharpening»: lenta y en agua, el acero nunca pierde el temple; pintar el bisel con rotulador sirve para encontrar y repetir el ángulo; en el cuero, siempre con la rueda alejándose del filo"
const SRC_TOR_KNIFE := "Tormek, «Knife sharpening»: afilar con el filo hacia la muela (más control) hasta que salga la rebaba en todo el filo, y luego la otra cara"
const SRC_EIN_WG := "Einhell TC-WG 200, manual: cuanta menos presión, más afilado; cuanta más, más arranque; la rebaba se quita en la rueda de cuero con pasta, por las dos caras; nunca el cuero en seco ni contra su giro"
const SRC_BURR := "Verhoeven 2004, «Experiments on knife sharpening»: en la piedra, contra el filo sale menos rebaba; el cuero con pasta la quita (sin pasta, no)"
const SRC_RUBRIC := "Rúbrica pedagógica del simulador (docs/taller/afilado-simulador.md, «Integración, oleada 2»): cuánto pesa cada fallo en la nota; lo que decide si hay fallo sale del modelo físico y de los datos con fuente"
const SRC_LINEAR := "docs/taller/afilado-simulador.md, §5: la subida de temperatura es casi proporcional al flujo de calor, y el flujo, a la fuerza (P = μ·F·v); orientativo, ±40 %"

## Puntos que se quitan de 10 por cada fallo (elección pedagógica, no física).
const RUBRIC := {
	"maquina_no": 4.0,
	"costado_muela": 2.0,
	"apoyo_lejos": 1.0,
	"abrasivo": 2.0,
	"sin_filo": 6.0,  # × parte del filo sin vértice: sin filo no hay afilado
	"desgaste": 4.0,  # broca: × parte sin quitar el desgaste del flanco
	"quemado": 5.0,
	"revenido": 2.0,  # desde 1 HRC, más 1 por cada HRC de más (hasta revenido_extra)
	"revenido_extra": 2.0,
	"revenido_leve": 1.0,  # de 0,1 a 1 HRC
	"color": 0.5,
	"angulo": 1.0,
	"broca_mal": 1.5,
	"broca_aviso": 0.5,
	"revision_max": 3.0,
	"se_cala": 1.0,
	"rebaba": 0.5,
	"cuero_contra": 1.0,
}
const FIT_NAMES := { "ideal": "ideal", "buena": "buena", "con_cuidado": "con cuidado", "no": "no sirve" }
const EDGE_TOLERANCE_DEG := 0.25  # el ángulo se da con medio grado: dentro del intervalo con ese margen


## Nota, criterios y consejos. f: los hechos que reúne SharpeningSim._facts().
## Devuelve { ran, finished, grade (null sin ensayo), grade_text, verdict, criteria: [{ id, title, ok, lost, text,
## source }], advice: [{ id, title, text, source }], edge_finish, summary, rubric_source }.
static func evaluate(f: Dictionary) -> Dictionary:
	var ran := bool(f.get("ran", false))
	var codes := {}
	for w in f.get("warnings", []):
		codes[str(w["code"])] = w
	var crit: Array = []
	var cap := 10.0
	# ── Seguridad y máquina (se miran antes de empezar) ──
	var idle: Dictionary = f.get("idle", {})
	if bool(idle.get("over_speed", false)):
		cap = 0.0
		var w: Dictionary = codes.get("exceso_velocidad", {})
		_crit(crit, "exceso_velocidad", "Velocidad", false, 10.0, "¡Peligro! La muela gira por encima de la velocidad máxima marcada: puede reventar. Nota 0.", str(w.get("source", "")))
	var fit: Dictionary = f.get("fit", {})
	if str(fit.get("fit", "")) == "no":
		_crit(crit, "maquina_no", "Máquina", false, RUBRIC["maquina_no"], "%s no es para %s: %s" % [str(f["machine"]["name"]), str(f["kind_name"]).to_lower(), str(fit["why"])], str(fit.get("source", "")))
	if codes.has("costado_muela"):
		_crit(crit, "costado_muela", "Seguridad", false, RUBRIC["costado_muela"], str(codes["costado_muela"]["message"]), str(codes["costado_muela"]["source"]))
	if codes.has("apoyo_lejos"):
		_crit(crit, "apoyo_lejos", "Seguridad", false, RUBRIC["apoyo_lejos"], str(codes["apoyo_lejos"]["message"]), str(codes["apoyo_lejos"]["source"]))
	for code in ["diamante_acero", "sic_acero", "abrasivo_metal_duro"]:
		if codes.has(code):
			_crit(crit, "abrasivo", "Abrasivo", false, RUBRIC["abrasivo"], str(codes[code]["message"]), str(codes[code]["source"]))
			break
	var kind := str(f.get("kind", "cuchillo"))
	var edge := bool(f.get("edge_tool", true))
	var hand: Dictionary = f.get("hand", {})
	var tool: Dictionary = f.get("tool", {})
	var rec: Dictionary = f.get("rec", {})
	var check: Dictionary = f.get("check", {})
	# Ángulo (antes de empezar también)
	var ang := _angle_check(kind, hand, tool, rec, f.get("mower_angle", {}))
	if not ang.is_empty() and not bool(ang["ok"]):
		_crit(crit, "angulo", "Ángulo", false, RUBRIC["angulo"], str(ang["text"]), str(ang["source"]))
	# Revisión de brocas y fresas
	if not check.is_empty():
		var lost_rev := 0.0
		for fd in check.get("findings", []):
			var sev := str(fd["severity"])
			if sev == "ok":
				continue
			var pts: float = RUBRIC["broca_mal"] if sev == "mal" else RUBRIC["broca_aviso"]
			pts = minf(pts, maxf(float(RUBRIC["revision_max"]) - lost_rev, 0.0))
			lost_rev += pts
			_crit(crit, "revision_" + str(fd["code"]), "Broca" if kind == "broca" else "Fresa", false, pts, str(fd["message"]), str(fd["source"]))
	# ── Resultado del ensayo ──
	var comb: Dictionary = f.get("combined", {})
	var bevel: Dictionary = f.get("bevel", {})
	if ran:
		var reached := float(bevel.get("reached", 0.0))
		if edge and reached < 1.0 - 1e-9:
			_crit(crit, "sin_filo", "Filo", false, float(RUBRIC["sin_filo"]) * (1.0 - reached), "El bisel no ha llegado al filo en el %s %% de la hoja: queda filo romo (hasta %s µm en el plano del vértice)." % [_fmt((1.0 - reached) * 100.0, 0), _fmt(float(bevel.get("gap_um", 0.0)), 0)], "sharpening_bevel.gd: retroceso de la cara = metal arrancado / área (Q/A, grinding.gd)")
		elif kind == "broca" and reached < 1.0 - 1e-9:
			_crit(crit, "desgaste", "Filo", false, float(RUBRIC["desgaste"]) * (1.0 - reached), "Falta quitar el desgaste del flanco en %s de los dos labios." % ("uno" if reached >= 0.5 else "ninguno de"), "grinding.gd: retroceso del flanco = metal arrancado / área de la punta que toca la muela")
		if not comb.is_empty():
			var loss := float(comb.get("max_loss_hrc", 0.0))
			if bool(comb.get("burned", false)):
				_crit(crit, "quemado", "Temperatura", false, RUBRIC["quemado"], "El filo se ha quemado: pasó de 723 °C (el acero empieza a austenizarse; la cifra del modelo ya no vale).", str(Heat.THRESHOLDS["burn_c"]["source"]))
			elif loss >= 1.0:
				var pts2 := float(RUBRIC["revenido"]) + minf(float(RUBRIC["revenido_extra"]), loss - 1.0)
				_crit(crit, "revenido", "Temperatura", false, pts2, "El filo ha perdido %s HRC: se ha pasado de su revenido." % _fmt(loss, 1), _hardness_source(f))
			elif loss >= 0.1:
				_crit(crit, "revenido_leve", "Temperatura", false, RUBRIC["revenido_leve"], "El filo ha perdido %s HRC: poco, pero ya se ha pasado de su revenido." % _fmt(loss, 2), _hardness_source(f))
			if int(comb.get("tinted_sections", 0)) > 0 and not bool(comb.get("burned", false)):
				var hs: Dictionary = f.get("hottest", {})
				var tn: Variant = hs.get("tint")
				_crit(crit, "color", "Temperatura", false, RUBRIC["color"], "Ha salido color de revenido (%s): el acero ya estaba perdiendo dureza antes." % (str((tn as Dictionary)["name"]) if tn is Dictionary else "color"), "Knife Steel Nerds 2019; «The colours of tempered steel», Nature 109:106 (1922)")
		if bool(f.get("stall_seen", false)):
			_crit(crit, "se_cala", "Motor", false, RUBRIC["se_cala"], "La muela se paraba con esa fuerza: con la máquina calada no se afila.", str(G.MOTORS["induccion"]["source"]))
		if edge and float(bevel.get("burr", 0.0)) > 0.0 and bool(f.get("has_leather", false)):
			_crit(crit, "rebaba", "Rebaba", false, RUBRIC["rebaba"], "Queda rebaba en el %s %% del filo: esta máquina tiene rueda de cuero para quitarla." % _fmt(float(bevel["burr"]) * 100.0, 0), SRC_EIN_WG)
		if codes.has("cuero_contra") and _used_leather(f):
			_crit(crit, "cuero_contra", "Cuero", false, RUBRIC["cuero_contra"], str(codes["cuero_contra"]["message"]), str(codes["cuero_contra"]["source"]))
	var lost := 0.0
	for c in crit:
		lost += float(c["lost"])
	var grade: Variant = null
	var verdict := "Sin afilar todavía: pulsa «Afilar»."
	var unfinished := ran and float(bevel.get("reached", 0.0)) < 1.0 - 1e-9 and (edge or kind == "broca")
	if ran:
		var gv := clampf(10.0 - lost, 0.0, cap)
		grade = gv
		if cap <= 0.0:
			verdict = "¡Peligro! Velocidad por encima de la marcada."
		elif unfinished:
			verdict = "Sin terminar: " + ("el bisel no ha llegado al filo en toda la hoja." if edge else "falta quitar el desgaste del flanco.")
		elif gv >= 9.0:
			verdict = "Muy bien afilado."
		elif gv >= 7.0:
			verdict = "Bien afilado."
		elif gv >= 5.0:
			verdict = "Aprobado, con cosas que mejorar."
		else:
			verdict = "Mal afilado."
	return {
		"ran": ran,
		"finished": bool(f.get("finished", false)),
		"grade": grade,
		"grade_text": "%s / 10" % _fmt_grade(float(grade)) if grade != null else "—",
		"verdict": verdict,
		"criteria": crit,
		"advice": advice(f, ang),
		"edge_finish": edge_finish(f),
		"summary": _summary(f),
		"rubric_source": SRC_RUBRIC,
	}


## Consejos, cada uno con su fuente: ángulo, velocidad y rpm, abrasivo, presión, pasadas, agua, máquina, rebaba, filo
## final, revisión de brocas y fresas, metal duro y seguridad.
static func advice(f: Dictionary, ang: Dictionary = {}) -> Array:
	var out: Array = []
	var kind := str(f.get("kind", "cuchillo"))
	var edge := bool(f.get("edge_tool", true))
	var hand: Dictionary = f.get("hand", {})
	var tool: Dictionary = f.get("tool", {})
	var rec: Dictionary = f.get("rec", {})
	var idle: Dictionary = f.get("idle", {})
	var cold: Dictionary = f.get("cold", {})
	var machine: Dictionary = f.get("machine", {})
	var wheel: Dictionary = f.get("wheel", {})
	var comb: Dictionary = f.get("combined", {})
	var bevel: Dictionary = f.get("bevel", {})
	var ran := bool(f.get("ran", false))
	var mk := str(machine.get("kind", ""))
	var wet := bool(wheel.get("wet", false))
	var force := float(hand.get("force_n", 10.0))
	# Ángulo
	if ang.is_empty():
		ang = _angle_check(kind, hand, tool, rec, f.get("mower_angle", {}))
	if not ang.is_empty():
		_tip(out, "angulo", "Ángulo", str(ang["advice"]), str(ang["source"]))
	# Velocidad y rpm
	var vs := float(idle.get("vs_ms", 0.0))
	var rpm := float(idle.get("rpm_no_load", 0.0))
	var d := float(idle.get("diameter_mm", 0.0))
	var speed_txt := "La muela va a %s m/s (%s rpm con Ø %s mm)." % [_fmt(vs, 1 if vs >= 10.0 else 2), _fmt(rpm, 0), _fmt(d, 0)]
	var speed_src := str(wheel.get("source", ""))
	if wet or mk == "lenta_humeda":
		speed_txt += " Lenta y en agua: es la velocidad de serie de la máquina y el filo no se calienta."
		speed_src += "; " + SRC_TOR_WAY
	elif mk == "amoladora":
		var steps: Array = machine.get("steps", [])
		if not steps.is_empty() and kind in ["hacha", "cortacesped"]:
			var slow := float(steps[0])
			if rpm > slow + 1e-9:
				var v_slow := Sharpening.peripheral_speed(d, slow)
				speed_txt += " Pon la rueda de velocidades en la posición más lenta (%s rpm, %s m/s): con la misma fuerza, %s veces menos calor." % [_fmt(slow, 0), _fmt(v_slow, 1), _fmt(vs / v_slow, 1)]
			else:
				speed_txt += " Posición más lenta: la que conviene para no destemplar."
			speed_src += "; " + Machines.SRC_TEAG
		elif steps.is_empty():
			speed_txt += " Sin regulación: a 12 000 rpm fijas calienta más que una de velocidad regulable; pasadas muy cortas."
			speed_src += "; " + Machines.SRC_TCAG
	var mounted_ab := str(wheel.get("abrasive_id", ""))
	var sr := speed_range(mounted_ab if mounted_ab != "" else "al2o3", wet)
	if not sr.is_empty() and not wet and mk != "lenta_humeda" and not bool(wheel.get("honing", false)):
		speed_txt += " Para afilar con %s (la muela montada) se recomiendan %s–%s m/s." % [_abr(mounted_ab if mounted_ab != "" else "al2o3"), _fmt(float(sr["min"]), 1), _fmt(float(sr["max"]), 1)]
		if vs > float(sr["max"]) * 1.0001:
			speed_txt += " Va más rápida: más calor con la misma fuerza."
		elif vs < float(sr["min"]) * 0.9999:
			speed_txt += " Va más despacio: arranca menos."
		speed_src += "; " + str(sr.get("source", ""))
	var max_v: Variant = idle.get("max_speed_ms")
	if max_v != null:
		speed_txt += " Nunca por encima de la máxima marcada en la muela o el disco: %s m/s." % _fmt(float(max_v), 1)
	if bool(idle.get("over_speed", false)):
		speed_txt = "¡Peligro! " + speed_txt
	_tip(out, "velocidad", "Velocidad y rpm", speed_txt, speed_src)
	# Abrasivo
	if not rec.is_empty():
		var mounted := str(wheel.get("abrasive_id", ""))
		var want := str(rec.get("abrasive_id", ""))
		var txt := "Para %s conviene %s. %s" % [str(f.get("steel_name", "")) if kind != "cortacesped" else "acero dulce", _abr(want), str(rec.get("abrasive_reason", ""))]
		if bool(wheel.get("honing", false)):
			txt = "La rueda de cuero no arranca metal: asienta el filo y quita la rebaba (con pasta). " + txt
		elif mounted != "" and mounted != want:
			txt += " La muela montada es de %s." % _abr(mounted)
		_tip(out, "abrasivo", "Abrasivo", txt, "sharpening.gd (choose_abrasive): Haefeli; Kraus & Winter; Norton; Malkin y Guo 2007; Brazda 2006; Zenkin et al. 2018")
	# Presión
	_tip_force(out, f, force)
	# Pasadas y agua (si el filo se ha calentado de más en seco)
	var hot := not comb.is_empty() and (bool(comb.get("burned", false)) or float(comb.get("max_loss_hrc", 0.0)) >= 0.1 or int(comb.get("tinted_sections", 0)) > 0)
	if ran and hot and not wet:
		var mpc := float(f.get("max_pass_contact_s", 0.0))
		_tip(out, "pasadas", "Pasadas", "Cada punto del filo estuvo hasta %s s seguidos bajo la muela: barre más deprisa o haz pasadas más cortas. En una muela seca, el vértice pasa el revenido en décimas de segundo." % _fmt(mpc, 2), Machines.SRC_KSN)
		var dip := bool(hand.get("dip", false))
		var water := "Mojas la hoja entre pasadas: baja el calor acumulado, pero no el pico de cada pasada." if dip else "Meter la hoja en agua entre pasadas baja el calor acumulado, aunque no el pico de cada pasada."
		if kind == "cuchillo":
			water += " Para un cuchillo, mejor una lenta en agua (Tormek, TC-WG 200, SCM8082): no pasa de ≈40 °C."
		if kind == "broca":
			water += " Pero una broca muy caliente no se mete de golpe en agua fría: puede agrietarse."
		_tip(out, "agua", "Agua", water, Machines.SRC_KSN + ("; " + Machines.SRC_TC9524_DRILL if kind == "broca" else ""))
	elif wet and edge:
		_tip(out, "agua", "Agua", "La muela gira en agua: mientras la cara no pasa de ≈130 °C, el agua se lleva el calor y el filo no se destempla.", SRC_TOR_WAY + "; " + str(Heat.THRESHOLDS["burnout_water_c"]["source"]))
	# Máquina
	var fit: Dictionary = f.get("fit", {})
	var best: Array = f.get("best", [])
	var names: Array[String] = []
	for b in best:
		if str(b["fit"]) in ["ideal", "buena"]:
			names.append(str(Machines.MACHINES[str(b["id"])]["name"]))
	var mtxt := "%s para %s: %s. %s" % [str(machine.get("name", "")), str(f.get("kind_name", "")).to_lower(), str(FIT_NAMES.get(str(fit.get("fit", "")), "")), str(fit.get("why", ""))]
	if not names.is_empty() and str(fit.get("fit", "")) != "ideal":
		mtxt += " Las mejores del catálogo para esto: %s." % ", ".join(names)
	_tip(out, "maquina", "Máquina", mtxt, str(fit.get("source", "")))
	# Rebaba y filo final
	if edge:
		var burr := float(bevel.get("burr", 0.0))
		var reached := float(bevel.get("reached", 0.0))
		var btxt := ""
		if ran and reached < 1.0 - 1e-9:
			btxt = "Aún no ha salido la rebaba en todo el filo (el bisel ha llegado al vértice en el %s %%): sigue por la misma cara hasta que salga en todo el largo; luego, la otra cara." % _fmt(reached * 100.0, 0)
		elif burr > 0.0:
			var hp: Dictionary = f.get("hone_passes", {})
			if bool(f.get("has_leather", false)):
				btxt = "Hay rebaba en el %s %% del filo: quítala en el cuero con pasta, por las dos caras y con la rueda alejándose del filo (unas %s pasadas; estimación)." % [_fmt(burr * 100.0, 0), _fmt(float(hp.get("value", 12.0)), 0)]
			else:
				btxt = "Hay rebaba en el %s %% del filo: esta máquina no tiene cuero; quítala con una piedra fina o un asentador de cuero con pasta, a mano." % _fmt(burr * 100.0, 0)
		elif float(bevel.get("burr_removed", 0.0)) > 0.0:
			btxt = "Rebaba quitada en el cuero: el filo queda asentado."
		else:
			btxt = "La rebaba sale cuando el bisel llega al vértice: afila una cara hasta notarla en todo el filo, luego la otra, y quítala en el cuero con pasta."
		if not bool(wheel.get("honing", false)) and str(hand.get("direction", "contra")) == "a_favor":
			btxt += " En la piedra, mejor con el filo hacia la muela («contra el filo»): menos rebaba y más control."
		_tip(out, "rebaba", "Rebaba", btxt, SRC_BURR + "; " + SRC_TOR_KNIFE + "; " + SRC_EIN_WG)
		var ef := edge_finish(f)
		if not ef.is_empty():
			_tip(out, "filo_final", "Filo final", str(ef["text"]), str(ef.get("source", Sharpening.SRC_VERHOEVEN)))
	# Revisión de brocas y fresas
	var check: Dictionary = f.get("check", {})
	if kind == "broca" and not check.is_empty():
		var dtxt := ""
		for fd in check.get("findings", []):
			dtxt += str(fd["message"]) + " "
		if mk == "afiladora_brocas":
			dtxt += "Con la MR-13A la pinza fija la broca: los labios salen iguales y la incidencia es la de la máquina."
		_tip(out, "broca", "Broca", dtxt.strip_edges(), G.SRC_TC9524_DRILL + "; " + G.SRC_US4031672 + "; " + G.SRC_MAZOFF)
	elif kind == "fresa" and not check.is_empty():
		var ftxt := ""
		for fd in check.get("findings", []):
			ftxt += str(fd["message"]) + " "
		ftxt += "En una afiladora universal con muela de copa, el dedo de apoyo se desplaza %s mm (0,0088 × ángulo × diámetro)." % _fmt(float(check.get("offset_mm", 0.0)), 2)
		_tip(out, "fresa", "Fresa", ftxt.strip_edges(), Sharpening.SRC_NACHI_EM + "; " + Sharpening.SRC_TC9524_MILL)
	if str(f.get("steel_id", "")) == "metal_duro":
		_tip(out, "metal_duro", "Metal duro", str(Sharpening.TOOL_MATERIALS["metal_duro"]["heat_note"]), str(Sharpening.TOOL_MATERIALS["metal_duro"]["source"]))
	# Seguridad
	var stxt := "Gafas o pantalla siempre y protección auditiva; al arrancar, ponte a un lado, nunca delante, y espera a que la muela llegue a su velocidad antes de apoyar."
	var ssrc := Machines.SRC_NPS
	if mk in ["banco", "banco_lenta", "combinada"]:
		stxt += " No amueles con el costado de una muela recta."
		var gap: Variant = f.get("rest_gap_max_mm")
		if gap != null:
			stxt += " El apoyo, a %s mm de la muela como mucho." % _fmt(float(gap), 1)
	elif mk == "amoladora":
		stxt += " Solo discos marcados para ≥ 12 000 rpm y 80 m/s, con el protector de desbaste; nunca un cuchillo de cocina con la amoladora."
		ssrc += "; " + Machines.SRC_TEAG
	_tip(out, "seguridad", "Seguridad", stxt, ssrc)
	return out


## Filo final según el último grano (Verhoeven 2004, EDGE_FINISH de sharpening.gd): { key, value_um, min_um, max_um,
## name, text, source, quality } o {} si no es una herramienta de filo. Sin ensayo o sin vértice, value_um es null.
static func edge_finish(f: Dictionary) -> Dictionary:
	if not bool(f.get("edge_tool", true)):
		return {}
	var bevel: Dictionary = f.get("bevel", {})
	var wheel_log: Array = f.get("wheel_log", [])
	var last_stone: Dictionary = {}
	var honed_after := false
	for e in wheel_log:
		if float(e["contact_s"]) <= 0.0:
			continue
		if bool(e["honing"]):
			if not last_stone.is_empty():
				honed_after = true
		else:
			last_stone = e
			honed_after = false
	if last_stone.is_empty():
		return { "key": "", "value_um": null, "name": "sin afilar", "text": "Todavía no se ha afilado con ninguna muela.", "source": Sharpening.SRC_VERHOEVEN, "quality": "primary" }
	if float(bevel.get("reached", 0.0)) < 1.0 - 1e-9:
		return { "key": "", "value_um": null, "name": "filo romo", "text": "Sin vértice en parte del filo: el bisel no ha llegado al filo y queda romo.", "source": "sharpening_bevel.gd", "quality": "estimate" }
	var g := int(last_stone["grit_number"])
	var removed := float(bevel.get("burr_removed", 0.0)) >= 1.0 - 1e-9 and float(bevel.get("burr", 0.0)) <= 0.0
	if g >= 180 and g <= 240:
		var key := "muela_220_cuero" if honed_after and removed else "muela_200"
		var e2: Dictionary = Sharpening.EDGE_FINISH[key]
		var span := _fmt(float(e2["value"]), 2) if float(e2["min"]) == float(e2["max"]) else "%s–%s" % [_fmt(float(e2["min"]), 1), _fmt(float(e2["max"]), 1)]
		var txt := "Filo de %s µm de ancho (%s, medido por Verhoeven 2004)." % [span, str(e2["name"])]
		if key == "muela_200" and float(bevel.get("burr", 0.0)) > 0.0:
			txt += " Con la rebaba todavía puesta: quítala para que el filo quede así."
		return { "key": key, "value_um": e2["value"], "min_um": e2["min"], "max_um": e2["max"], "name": e2["name"], "text": txt, "source": e2["source"], "quality": e2["quality"] }
	if g > 0 and g < 180:
		var ref: Dictionary = Sharpening.EDGE_FINISH["muela_200"]
		return { "key": "", "value_um": null, "min_um": ref["min"], "max_um": null, "name": "grano %d" % g,
			"text": "Grano %d, más basto que la muela de 200: Verhoeven no midió el filo que deja; como poco, el de la de 200 (%s–%s µm). Para un filo fino, termina en una piedra de 200 o más fina y en el cuero." % [g, _fmt(float(ref["min"]), 0), _fmt(float(ref["max"]), 0)],
			"source": str(ref["source"]), "quality": "estimate" }
	return { "key": "", "value_um": null, "name": "sin medida", "text": "No hay medida del filo que deja esta muela (%s)." % str(last_stone["grit"]), "source": Sharpening.SRC_VERHOEVEN, "quality": "estimate" }


## Ángulo afilado frente al recomendado: { ok, text (fallo), advice (consejo), source } o {} (brocas y fresas: los
## revisa drill_check o mill_check).
static func _angle_check(kind: String, hand: Dictionary, tool: Dictionary, rec: Dictionary, mower: Dictionary = {}) -> Dictionary:
	var beta := float(hand.get("angle_deg", 0.0))
	var pulse := str(hand.get("angle_mode", "plantilla")) == "pulso"
	var wob := float(hand.get("wobble_deg", 0.0))
	match kind:
		"cuchillo", "hacha":
			var angles: Dictionary = rec.get("angles", {})
			var ps: Dictionary = angles.get("per_side", {})
			if ps.is_empty():
				return {}
			var lo := float(ps["min"])
			var hi := float(ps["max"])
			var ok := beta >= lo - EDGE_TOLERANCE_DEG and beta <= hi + EDGE_TOLERANCE_DEG
			var adv := "Afilas a %s° por lado (%s° en total). Para %s se recomiendan %s–%s° por lado (%s–%s° en total)." % [_fmt(beta, 1), _fmt(2.0 * beta, 1), str(angles.get("use_name", "")), _fmt(lo, 1), _fmt(hi, 1), _fmt(2.0 * lo, 0), _fmt(2.0 * hi, 0)]
			if beta < lo - EDGE_TOLERANCE_DEG:
				adv += " Sube el ángulo: un filo tan fino se mella antes."
			elif beta > hi + EDGE_TOLERANCE_DEG:
				adv += " Baja el ángulo: corta peor."
			var bevel := float(tool.get("bevel_deg", beta))
			if beta < bevel - 0.5:
				adv += " Es más bajo que el bisel que tenía (%s°): hay que rehacer el bisel entero antes de llegar al filo." % _fmt(bevel, 1)
			elif beta > bevel + 0.5:
				adv += " Es más alto que el bisel que tenía (%s°): solo sale un microbisel en el filo, que llega antes." % _fmt(bevel, 1)
			if pulse:
				adv += " A pulso el ángulo baila (±%s°) y el bisel sale redondeado: con plantilla o galga se repite siempre el mismo; pintar el bisel con rotulador ayuda a encontrarlo." % _fmt(wob, 1)
			var txt := "Ángulo de %s° por lado, fuera de lo recomendado para %s (%s–%s°)." % [_fmt(beta, 1), str(angles.get("use_name", "")), _fmt(lo, 1), _fmt(hi, 1)]
			return { "ok": ok, "text": txt, "advice": adv, "source": str(ps.get("source", "")) + ("; " + SRC_TOR_WAY if pulse else "") }
		"cortacesped":
			if mower.is_empty():
				return {}
			var m_lo := float(mower["min"])
			var m_hi := float(mower["max"])
			var ok2 := beta >= m_lo - EDGE_TOLERANCE_DEG and beta <= m_hi + EDGE_TOLERANCE_DEG
			var adv2 := "Afilas a %s°. Mantén el ángulo original (≈%s°; %s–%s° en algunas marcas) y amuela solo la cara de arriba; quita lo mismo de los dos extremos y equilibra la cuchilla." % [_fmt(beta, 1), _fmt(float(mower["value"]), 0), _fmt(float(mower["brands_min"]), 0), _fmt(float(mower["brands_max"]), 0)]
			return { "ok": ok2, "text": "Ángulo de %s°, fuera del de las cuchillas (%s–%s°)." % [_fmt(beta, 1), _fmt(m_lo, 0), _fmt(m_hi, 0)], "advice": adv2, "source": str(mower["source"]) }
		"broca":
			return {}
		"fresa":
			return {}
	return {}


## Consejo sobre la fuerza: el motor que se frena o se cala, y la fuerza que no pasaría del revenido (la subida de
## temperatura es casi proporcional a la fuerza).
static func _tip_force(out: Array, f: Dictionary, force: float) -> void:
	var cold: Dictionary = f.get("cold", {})
	var idle: Dictionary = f.get("idle", {})
	var comb: Dictionary = f.get("combined", {})
	var ran := bool(f.get("ran", false))
	var wheel: Dictionary = f.get("wheel", {})
	var name := _force_name(force, f.get("hand_force_names", G.HAND_FORCE))
	var src := str(G.HAND_FORCE["ligera"]["source"])
	var txt := ""
	if bool(cold.get("stalled", false)):
		txt = "Con %s N la muela se para: el motor no da el par. Retira la pieza, espera a que recupere el giro y apoya con menos fuerza." % _fmt(force, 0)
		for w in cold.get("warnings", []):
			if str(w["code"]) == "se_cala":
				src = str(w["source"])
	elif bool(cold.get("overloaded", false)):
		txt = "Con %s N el motor se frena: la muela baja de %s a %s rpm. Menos fuerza." % [_fmt(force, 0), _fmt(float(idle.get("rpm_no_load", 0.0)), 0), _fmt(float(cold.get("rpm", 0.0)), 0)]
		src = str(G.MOTORS["induccion"]["source"])
	if ran and not comb.is_empty():
		var peak := float(comb.get("peak_edge_c", Heat.AMBIENT_C))
		var thr: Variant = f.get("temper_threshold_c")
		if bool(comb.get("burned", false)):
			txt += (" " if txt != "" else "") + "Con %s N el filo se ha quemado (> 723 °C): baja mucho la fuerza y acorta las pasadas, o cambia a una máquina lenta en agua." % _fmt(force, 0)
			src += "; " + str(Heat.THRESHOLDS["burn_c"]["source"])
		elif thr != null and peak > float(thr) and force > 0.0:
			var t_thr := float(thr)
			var f_ok := force * (t_thr - Heat.AMBIENT_C) / maxf(peak - Heat.AMBIENT_C, 1e-9)
			txt += (" " if txt != "" else "") + "Con %s N («%s») el filo llegó a %s °C, y para lo que duró cada contacto (%s s) el revenido de este acero equivale a ≈%s °C (Hollomon–Jaffe): con ≈%s N no lo pasaría (la subida de temperatura es casi proporcional a la fuerza; ±40 %%)." % [_fmt(force, 0), name, _fmt(peak, 0), _fmt(float(f.get("max_pass_contact_s", 0.0)), 2), _fmt(t_thr, 0), _fmt(f_ok, 1)]
			src += "; " + str(Heat.THRESHOLDS["hollomon_jaffe_c"]["source"]) + "; " + SRC_LINEAR
		elif txt == "":
			txt = "La fuerza (%s N, «%s») no ha llevado el filo más allá de su revenido: bien." % [_fmt(force, 0), name]
	elif txt == "":
		txt = "Empieza con presión ligera (%s N, «%s»): más fuerza, más calor y más arranque; un motor pequeño se frena o se cala." % [_fmt(force, 0), name]
	if bool(wheel.get("wet", false)):
		txt += " En la muela húmeda: cuanta menos presión, más afilado; cuanta más, más arranque."
		src += "; " + SRC_EIN_WG
	_tip(out, "presion", "Presión", txt, src)


## Nombre de la fuerza más cercana de la escala de grinding.gd (estimación: no hay medida publicada).
static func _force_name(force: float, names: Dictionary) -> String:
	var best := ""
	var dist := INF
	for k in names:
		var v := float(names[k]["value"])
		if absf(v - force) < dist:
			dist = absf(v - force)
			best = str(k).replace("_", " ")
	return best


static func _summary(f: Dictionary) -> Dictionary:
	var comb: Dictionary = f.get("combined", {})
	var bevel: Dictionary = f.get("bevel", {})
	var hs: Dictionary = f.get("hottest", {})
	return {
		"time_s": f.get("time_s", 0.0), "passes_done": f.get("passes_done", 0), "removed_mm3": f.get("removed_mm3", 0.0),
		"thermal": bool(f.get("thermal", false)),
		"peak_edge_c": comb.get("peak_edge_c") if not comb.is_empty() else null,
		"burned": bool(comb.get("burned", false)),
		"max_loss_hrc": comb.get("max_loss_hrc") if not comb.is_empty() else null,
		"tint": hs.get("tint") if not hs.is_empty() else null,
		"softened_width_mm": hs.get("softened_width_mm", 0.0) if not hs.is_empty() else 0.0,
		"reached": bevel.get("reached", 0.0), "progress": bevel.get("progress", 0.0),
		"burr": bevel.get("burr", 0.0), "burr_removed": bevel.get("burr_removed", 0.0),
		"max_pass_contact_s": f.get("max_pass_contact_s", 0.0),
	}


## Velocidad periférica recomendada para amolar herramientas con un abrasivo (SPEED_RANGES de sharpening.gd: Nachi
## para el corindón y el SiC; Kraus & Winter para el CBN y el diamante, en seco o en húmedo).
static func speed_range(abrasive_id: String, wet: bool) -> Dictionary:
	var key := abrasive_id
	if abrasive_id in ["cbn", "diamante"]:
		key = abrasive_id + ("_humedo" if wet else "_seco")
	return (Sharpening.SPEED_RANGES.get(key, {}) as Dictionary).duplicate()


static func _used_leather(f: Dictionary) -> bool:
	for e in f.get("wheel_log", []):
		if bool(e["honing"]) and float(e["contact_s"]) > 0.0:
			return true
	return false


static func _hardness_source(f: Dictionary) -> String:
	var hs: Dictionary = f.get("hottest", {})
	var h: Variant = hs.get("hardness")
	return str((h as Dictionary).get("source", "")) if h is Dictionary else str(Heat.THRESHOLDS["hollomon_jaffe_c"]["source"])


static func _crit(list: Array, id: String, title: String, ok: bool, lost: float, text: String, source: String) -> void:
	list.append({ "id": id, "title": title, "ok": ok, "lost": lost, "text": text, "source": source })


static func _tip(list: Array, id: String, title: String, text: String, source: String) -> void:
	list.append({ "id": id, "title": title, "text": text, "source": source })


static func _abr(id: String) -> String:
	return str({ "al2o3": "corindón (Al₂O₃)", "sic": "SiC", "cbn": "CBN", "diamante": "diamante" }.get(id, "sin dato"))


## Nota con un decimal (media nota si hace falta): «8,5».
static func _fmt_grade(x: float) -> String:
	return _fmt(x, 1)


## Número con coma decimal y sin ceros de sobra (toFixed de JavaScript, como grinding.gd).
static func _fmt(x: float, decimals: int) -> String:
	var s := Js.to_fixed(x, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")
