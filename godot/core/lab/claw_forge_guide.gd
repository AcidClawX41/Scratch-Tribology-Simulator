## Tribología biológica · reforja experimental: el guiado botón a botón del tutorial (unidad 5x), sin nodos y determinista.
##
## Para el paso del tutorial que se sigue y el estado de ahora, dice la acción siguiente: qué control del panel o qué objeto de
## la vista 3D hay que pulsar, con el valor exacto de la receta o lo que falta (core/shared/guide_target.gd). Cada receta tiene
## su secuencia propia porque sale de sus propios argumentos (los del paso, los de ClawForge.recommended): sus polvos y sus
## gramos, su modo, su temperatura, su tiempo, su presión, su atmósfera, su molde, su enfriado, sus herramientas de tallar y su
## pulido; en la mesa de soldar, lo de su método (el láser pulsado, el micro-TIG o la soldadura fuerte de plata).
## El objetivo cambia con el estado: si falta cobalto, el botón de dosis del cobalto; con la mezcla lista, «Cargar el crisol»;
## si la persona hace otra cosa (gira otro dial, cambia de herramienta), el siguiente sale de lo que hay ahora, no de un guion.
## Cada objetivo lleva la orden del estado que manda su control (op y args, la misma que su botón): un test juega el tutorial
## entero pulsando solo eso (tests/lab/test_claw_forge_guide.gd).
## Solo con el tutorial encendido y el «Guiado» encendido; con el tutorial terminado, nada.
## Uso: lo llama ClawForgeState.guide_view(); la página y la escena pintan su resultado.
extends RefCounted

const Guide = preload("res://core/shared/guide_target.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const ClawWeld = preload("res://core/lab/claw_weld.gd")
const Js = preload("res://core/shared/js.gd")

## La vista de la cámara que enseña cada objeto de la escena (forge_3d.gd: VIEWS).
const SCENE_VIEW := {
	"balanza": "banco", "crisol": "banco", "tienda": "banco", "acrilico": "banco", "cera": "banco",
	"horno": "horno", "arrancar": "horno", "sacar": "horno", "ventana": "horno",
	"pieza": "pieza", "muela": "taller", "sierra": "taller", "fresa": "taller", "pulidora": "taller", "barrera": "taller",
	"pistola": "taller", "garra": "taller", "soldadura": "soldar", "costura": "soldar",
}
## Lo que se ilumina en un paso informativo (ClawForgeState.STEP_HIGHLIGHT) → el objeto de la escena que lo enseña.
const HIGHLIGHT_SCENE := { "puerta": "ventana", "adhesivo": "garra", "carga": "garra" }
## Cómo se nombra cada mando del horno en la etiqueta («Dial de temperatura: 1450 °C») y en el aviso («Pon el dial de
## temperatura a 1450 °C»; los selectores, «Pon la atmósfera en «Vacío»»).
const CONTROL_WORDS := {
	"modo": ["Selector de modo", "el selector de modo"], "temp_c": ["Dial de temperatura", "el dial de temperatura"],
	"time_s": ["Dial del tiempo", "el dial del tiempo"], "pressure_mpa": ["Dial de presión", "el dial de presión"],
	"methane": ["Dial del metano", "el dial del metano"], "atmosphere": ["Atmósfera", "la atmósfera"],
	"mold": ["Molde", "el selector «Molde»"], "cool": ["Enfriar", "el selector «Enfriar»"],
}
## El orden de los mandos de la marcha (el de la tarjeta «El horno»): primero el modo, luego cada dial y cada selector.
const FIRE_ORDER := ["modo", "temp_c", "time_s", "pressure_mpa", "atmosphere", "mold", "methane"]
## El sitio de la escena de cada herramienta de tallar (ClawForgeState.TOOL_AT).
const TOOL_SCENE := { "sierra": "sierra", "muela_gruesa": "muela", "fresa": "fresa", "muela_fina": "muela", "pulidora": "pulidora" }
## Un deslizador del taller da su valor con la resolución de su recorrido: se da por puesto dentro de esta fracción.
const SLIDER_TOL := 0.01
## Los pasos que se pueden hacer con el horno en marcha (los demás esperan a que acabe).
const WHILE_RUNNING := ["pesar"]


## Los números, con Js y el punto decimal, como el panel y la escena de la reforja: en una misma pantalla, una sola forma.
## El objetivo de ahora (Guide.make) o Guide.off(). st: un ClawForgeState; bench: su bench_view(); highlight: lo que el
## tutorial ilumina en el paso (STEP_HIGHLIGHT).
static func target(st: Object, bench: Dictionary, highlight: String) -> Dictionary:
	if not bool(st.get("tutorial_on")) or not bool(st.get("guide_on")) or bool(st.call("tutorial_done")):
		return Guide.off()
	var step: Dictionary = st.call("current_step")
	if step.is_empty():
		return Guide.off()
	var t := _for_step(st, step, bench)
	return t if not t.is_empty() else _next(step, highlight)


static func _for_step(st: Object, step: Dictionary, bench: Dictionary) -> Dictionary:
	var sid := String(step.id)
	if bool(st.call("running")) and not WHILE_RUNNING.has(sid):
		return _wait(sid)
	var check := String(step.get("check", ""))
	if check == "" or step.get("done") == true:
		return {}
	var args: Variant = step.get("args")
	var a: Dictionary = args if args is Dictionary else {}
	var process := String(st.get("process"))
	match sid:
		"pesar":
			return _weigh(st, sid, bench)
		"modo":
			return _control(st, sid, "modo", String(ForgeData.RECIPES[process].mode)) if ForgeData.RECIPES.has(process) else {}
		"meter":
			var tm := _control(st, sid, "modo", String(ForgeData.RECIPES[process].mode)) if ForgeData.RECIPES.has(process) else {}
			return tm if not tm.is_empty() else _insert(st, sid)
		"parametros":
			return _fire(st, sid, a)
		"enfriar":
			var tc := _control(st, sid, "cool", String(args)) if args is String else {}
			if not tc.is_empty():
				return tc
			return Guide.make("enfriar", "panel", "horno", "Pulsa aquí: Sacar y enfriar (E)", "Pulsa «Sacar y enfriar» (E)", "", "sacar", "enfriar", "cool_piece", [], sid)
		"cera":
			var tw := _control(st, sid, "mold", String(a.get("mold", "")))
			if not tw.is_empty():
				return tw
			if bool(a.get("compensate", true)) != bool(st.get("compensate")):
				return Guide.make("cera_medida", "panel", "banco", "Pulsa aquí: Cera a la medida", "Enciende «Cera a la medida»: compensa lo que encoge", "", "cera", "cera_medida", "set_compensate", [bool(a.get("compensate", true))], sid)
			return Guide.make("cera:cera", "panel", "banco", "Pulsa aquí: Modelo de cera (C)", "Pulsa «Modelo de cera» (C)", "", "cera", "cera:cera", "make_wax", [], sid)
		"revestir":
			var tr := _control(st, sid, "mold", String(a.get("mold", "")))
			if not tr.is_empty():
				return tr
			return Guide.make("cera:revestir", "panel", "banco", "Pulsa aquí: Revestir (C)", "Pulsa «Revestir» (C)", "", "cera", "cera:revestir", "invest", [], sid)
		"quemar":
			for e: Array in [["modo", "calentar"], ["temp_c", float(a.get("temp_c", 0.0))], ["time_s", float(a.get("time_s", 0.0))]]:
				var tq := _control(st, sid, String(e[0]), e[1])
				if not tq.is_empty():
					return tq
			if String(st.call("charge_inside")) != "molde":
				return _insert(st, sid)
			return _start(sid)
		"romper":
			return Guide.make("cera:romper", "panel", "banco", "Pulsa aquí: Romper el molde (C)", "Pulsa «Romper el molde» (C)", "", "cera", "cera:romper", "divest", [], sid)
		"tocho", "cortar_bebedero", "desbastar", "vaciar", "forma", "limar", "repasar", "limar_costura":
			return _carve(st, sid, a)
		"proteger":
			return _protect(st, sid, a)
		"recubrir":
			return _coat(st, sid, a)
		"pulir", "pulir_soldada":
			return _polish(st, sid, a)
		"ajuste":
			var gap := float(a.get("gap_mm", -1.0))
			if gap >= 0.0 and not _near(float(st.get("bond_p").gap_mm), gap):
				var gt := _num(gap, 2) + " mm"
				return Guide.make("holgura", "panel", "taller", "Holgura: %s" % gt, "Pon la holgura a %s" % gt, gt, "garra", "holgura", "set_bond", ["gap_mm", gap], sid)
			return Guide.make("ajuste", "panel", "taller", "Pulsa aquí: Probar el ajuste (U)", "Pulsa «Probar el ajuste» (U)", "", "garra", "ajuste", "fit_test", [], sid)
		"elegir":
			var stone: Variant = ForgeData.inlay_entry(String(st.get("stone")))
			var nm := String(stone.name).to_lower() if stone != null else String(st.get("stone"))
			return Guide.make("cargar", "panel", "banco", "Pulsa aquí: Comprar la piedra (L)", "Compra la piedra: %s (L)" % nm, nm, "tienda", "cargar", "load_crucible", [], sid)
		"mezclar":
			return Guide.make("cargar", "panel", "banco", "Pulsa aquí: Mezclar el acrílico (L)", "Pulsa «Mezclar el acrílico» (L)", "", "acrilico", "cargar", "load_crucible", [], sid)
		"preparar":
			return _weld_setup(st, sid, a)
		"alinear":
			return Guide.make("soldar_alinear", "panel", "soldar", "Pulsa aquí: Alinear (I)", "Alinea las piezas: «Alinear» (I) o arrastra la punta", "", "costura", "soldar_alinear", "weld_align_pieces", [], sid)
		"soldar":
			return _weld_seam(st, sid)
	return {}


## Un paso informativo (o ya hecho): «Siguiente», con el objeto que el paso enseña en la escena.
static func _next(step: Dictionary, highlight: String) -> Dictionary:
	var sc := String(HIGHLIGHT_SCENE.get(highlight, highlight))
	if ForgeData.CONTROLS.any(func(c: Dictionary) -> bool: return String(c.id) == sc):
		sc = "mando:" + sc
	var view := "horno" if sc.begins_with("mando:") else String(SCENE_VIEW.get(sc, ""))
	if String(step.id) == "vigilar":
		view = "dentro"
		sc = ""
	var hint := "Lee el paso y pulsa «Siguiente» (N)"
	if String(step.id) == "pasar":
		hint = "Pulsa «Siguiente» (N) y luego «Pasar a la cetrería»"
	if String(step.get("check", "")) != "" and step.get("done") == true:
		hint = "Hecho: pulsa «Siguiente» (N)"
	return Guide.make("siguiente", "panel", view, "Pulsa aquí: Siguiente (N)", hint, "", sc, "siguiente", "tutorial_next", [], String(step.id))


## Con el horno en marcha: esperar a que acabe, o «Acabar ya» (el reloj ya lo pinta la página: el objetivo no cambia en cada
## fotograma de la marcha).
static func _wait(sid: String) -> Dictionary:
	return Guide.make("acabar", "panel", "dentro", "Pulsa aquí: Acabar ya (Espacio)", "La marcha va: espera o pulsa «Acabar ya» (Espacio)", "", "", "acabar", "skip", [], sid)


## Pesar (5w): cada polvo de la receta hasta su objetivo con sus botones de dosis (de la grande a la fina, sin pasarse), la tara
## antes de pesar el siguiente, lo que la balanza dice que falta (o que sobra) y, con la mezcla en receta, «Cargar el crisol».
static func _weigh(st: Object, sid: String, bench: Dictionary) -> Dictionary:
	var pan: Dictionary = st.get("pan")
	var ms: Dictionary = st.get("forge").mix_status(pan)
	if bool(ms.ok):
		return Guide.make("cargar", "panel", "banco", "Pulsa aquí: Cargar el crisol (L)", "Pulsa «Cargar el crisol» (L)", "", "crisol", "cargar", "load_crucible", [], sid)
	var jars := {}
	for j: Dictionary in bench.get("jars", []):
		jars[String(j.id)] = j
	var fix: Dictionary = ms.fix
	match String(fix.kind):
		"vaciar":
			return _empty(sid)
		"quitar":
			for k: String in fix.take:
				var j: Dictionary = jars.get(k, {})
				if j.is_empty():
					continue
				var take := ClawForge.fmt_mass(float(fix.take[k]), float(j.target_g))
				var dl := String(j.minus.label)
				return Guide.make("quitar:" + k, "panel", "banco", "Pulsa aquí: %s de %s" % [dl, _lower_first(String(j.name))], "Te has pasado: quita %s de %s" % [take, String(j.formula)], take, "tarro:" + k, "quitar:" + k, "add_powder", [k, float(j.minus.g)], sid)
	var plan: Dictionary = ms.plan
	var total := float(st.call("pan_total"))
	for p: Dictionary in plan.get("powders", []):
		var id := String(p.id)
		var j: Dictionary = jars.get(id, {})
		if j.is_empty():
			continue
		var have := float(pan.get(id, 0.0))
		var tg := float(p.targetG)
		var doses: Array = j.doses
		for i in doses.size():
			var g := float(doses[i].g)
			if have + g > tg + 1e-12:
				continue
			# antes del primer gramo de otro polvo, la tara: la pantalla a cero para leer solo lo que se echa
			if have <= 0.0 and total > 0.0 and float(st.get("tare_g")) < total - 1e-9:
				return Guide.make("tara", "panel", "banco", "Pulsa aquí: Tara (Z)", "Pulsa «Tara» (Z): la balanza a cero para pesar el %s" % String(p.formula), "", "balanza", "tara", "tare", [], sid)
			return _dose(sid, j, i, tg - have, tg, have <= 0.0)
	# ya no cabe ninguna dosis sin pasarse: lo que dice la balanza que falta, con la dosis más fina
	if String(fix.kind) in ["echar", "compensar"]:
		for k: String in fix.add:
			var j2: Dictionary = jars.get(k, {})
			if j2.is_empty() or float(fix.add[k]) <= 0.0:
				continue
			return _dose(sid, j2, (j2.doses as Array).size() - 1, float(fix.add[k]), float(j2.target_g), false)
	return _empty(sid)


static func _dose(sid: String, j: Dictionary, i: int, left_g: float, target_g: float, first: bool) -> Dictionary:
	var id := String(j.id)
	var left := ClawForge.fmt_mass(left_g, target_g)
	var dl := String(j.doses[i].label)
	var hint := ("Ahora toca añadir %s de %s" if first else "Añade %s de %s") % [left, String(j.formula)]
	return Guide.make("dosis:%s:%d" % [id, i], "panel", "banco", "Pulsa aquí: %s de %s" % [dl, _lower_first(String(j.name))], hint, left, "tarro:" + id, "dosis:%s:%d" % [id, i], "add_powder", [id, float(j.doses[i].g)], sid)


static func _empty(sid: String) -> Dictionary:
	return Guide.make("vaciar", "panel", "banco", "Pulsa aquí: Vaciar (Retroceso)", "Vacía el plato (Retroceso) y vuelve a pesar", "", "balanza", "vaciar", "clear_pan", [], sid)


## Un mando del horno al valor exacto: un selector a su opción (el botón de esa opción) o un dial a su marca (el deslizador).
## {} si ya está.
static func _control(st: Object, sid: String, cid: String, want: Variant) -> Dictionary:
	var c := _control_data(cid)
	if c.is_empty():
		return {}
	var dial: Dictionary = st.get("dial")
	var words: Array = CONTROL_WORDS[cid]
	if c.has("options"):
		var opt := String(want)
		if opt == "" or String(dial[cid]) == opt:
			return {}
		var nm := String((c.option_names as Dictionary).get(opt, opt))
		var pid := "mando:%s:%s" % [cid, opt]
		return Guide.make(pid, "panel", "horno", "%s: %s" % [String(words[0]), nm], "Pon %s en «%s»" % [String(words[1]), nm], nm, "mando:" + cid, pid, "set_control", [cid, opt], sid)
	var v := float(want)
	if absf(float(dial[cid]) - v) < 1e-9:
		return {}
	var vt := String(st.call("value_text", cid, v))
	return Guide.make("mando:" + cid, "panel", "horno", "%s: %s" % [String(words[0]), vt], "Pon %s a %s" % [String(words[1]), vt], vt, "mando:" + cid, "mando:" + cid, "set_control", [cid, v], sid)


static func _control_data(cid: String) -> Dictionary:
	for c: Dictionary in ForgeData.CONTROLS:
		if String(c.id) == cid:
			return c
	return {}


## Meter la carga en la máquina del modo (M, o un clic en la puerta del horno).
static func _insert(st: Object, sid: String) -> Dictionary:
	var iv: Dictionary = st.call("inside_view")
	var what := String(iv.get("next_name", ""))
	var hint := "Mete %s en su máquina: «Meter la carga» (M)" % what if what != "" else "Pulsa «Meter la carga» (M)"
	return Guide.make("meter", "panel", "horno", "Pulsa aquí: Meter la carga (M)", hint, "", "ventana", "meter", "insert_charge", [], sid)


static func _start(sid: String) -> Dictionary:
	return Guide.make("arrancar", "panel", "horno", "Pulsa aquí: Arrancar (Intro)", "Pulsa el botón rojo «Arrancar» (Intro)", "", "arrancar", "arrancar", "start", [], sid)


## Los parámetros de la marcha: cada mando a lo que dice el paso (sus args, con el tiempo en su marca del dial), la carga dentro
## y «Arrancar».
static func _fire(st: Object, sid: String, a: Dictionary) -> Dictionary:
	for cid: String in FIRE_ORDER:
		var key := "mode" if cid == "modo" else cid
		if not a.has(key):
			continue
		var want: Variant = a[key]
		if cid == "methane":
			want = float(want) * 100.0
		var t := _control(st, sid, cid, want)
		if not t.is_empty():
			return t
	if String(st.call("charge_inside")) == "":
		return _insert(st, sid)
	return _start(sid)


## Tallar por pasadas: la herramienta del paso, su material, el agua y la fuerza, y una pasada (T) en su máquina.
static func _carve(st: Object, sid: String, a: Dictionary) -> Dictionary:
	var tool := String(a.get("tool", st.get("carve_tool")))
	var tname := String(ForgeData.CARVE_TOOLS[tool].short) if ForgeData.CARVE_TOOLS.has(tool) and ForgeData.CARVE_TOOLS[tool].has("short") else _tool_label(tool)
	var at := String(TOOL_SCENE.get(tool, "muela"))
	if String(st.get("carve_tool")) != tool:
		return Guide.make("herramienta:" + tool, "panel", "taller", "Herramienta: %s" % tname, "Elige la herramienta «%s» (G)" % tname, tname, at, "herramienta:" + tool, "set_carve_tool", [tool], sid)
	var cp: Dictionary = st.get("carve_p")
	var abr := String(a.get("abrasive", ""))
	if abr != "" and String(cp.abrasive) != abr:
		var an := _abrasive_name(abr)
		return Guide.make("tallar_material:" + abr, "panel", "taller", "Material de la herramienta: %s" % an, "Elige el material «%s» para tallar" % an, an, at, "tallar_material:" + abr, "set_carve", ["abrasive", abr], sid)
	if a.has("coolant") and bool(a.coolant) != bool(cp.coolant):
		return Guide.make("tallar_agua", "panel", "taller", "Pulsa aquí: Con agua", "Enciende «Con agua»: en seco se agrieta", "", at, "tallar_agua", "set_carve", ["coolant", bool(a.coolant)], sid)
	if a.has("force_n") and not _near(float(cp.force_n), float(a.force_n)):
		var ft := _num(float(a.force_n), 0) + " N"
		return Guide.make("tallar_fuerza", "panel", "taller", "Fuerza: %s" % ft, "Pon la fuerza a %s" % ft, ft, at, "tallar_fuerza", "set_carve", ["force_n", float(a.force_n)], sid)
	return Guide.make("pasada", "panel", "taller", "Pulsa aquí: Una pasada (T)", "Da una pasada con «%s» (T)" % tname, tname, at, "pasada", "carve_pass", [false], sid)


static func _tool_label(tool: String) -> String:
	return { "sierra": "Sierra", "muela_gruesa": "Muela gruesa", "fresa": "Fresa", "muela_fina": "Muela fina", "pulidora": "Pulidora" }.get(tool, tool)


## El nombre corto de un abrasivo, el de la tarjeta del taller («diamante», «CBN»).
static func _abrasive_name(id: String) -> String:
	var a: Dictionary = ForgeData.ABRASIVES.get(id, {})
	return String(a.get("name", id)).replace("Muela o pasta de ", "").replace("Muela de ", "").replace("carburo de silicio verde", "carburo de silicio")


## Proteger la carne viva: la barrera del paso, su espesor y «Proteger» (B).
static func _protect(st: Object, sid: String, a: Dictionary) -> Dictionary:
	var bp: Dictionary = st.get("barrier_p")
	var b := String(a.get("barrier", ""))
	if b != "" and String(bp.barrier) != b:
		var bn := String(ForgeData.BARRIERS[b].name)
		return Guide.make("barrera:" + b, "panel", "taller", "Barrera: %s" % bn, "Elige la barrera «%s»" % bn, bn, "barrera", "barrera:" + b, "set_barrier", ["barrier", b], sid)
	if a.has("thickness_mm") and not _near(float(bp.thickness_mm), float(a.thickness_mm)):
		var tt := _num(float(a.thickness_mm), 1) + " mm"
		return Guide.make("barrera_espesor", "panel", "taller", "Espesor: %s" % tt, "Pon el espesor de la barrera a %s" % tt, tt, "barrera", "barrera_espesor", "set_barrier", ["thickness_mm", float(a.thickness_mm)], sid)
	return Guide.make("proteger", "panel", "taller", "Pulsa aquí: Proteger (B)", "Pulsa «Proteger» (B): la barrera sobre la carne viva", "", "barrera", "proteger", "protect", [], sid)


## Recubrir (la garra viva, ficción): el método, el tiempo, lo que se cubre de la punta y «Recubrir» (R). La garra viva va sola
## como objetivo (ClawForgeState.coat).
static func _coat(st: Object, sid: String, a: Dictionary) -> Dictionary:
	var cp: Dictionary = st.get("coat_p")
	var m := String(a.get("method", ""))
	if m != "" and String(cp.method) != m:
		var mn := String(ForgeData.COATINGS[m].name)
		return Guide.make("recubrimiento:" + m, "panel", "taller", "Recubrimiento: %s" % mn, "Elige «%s»" % mn, mn, "pistola", "recubrimiento:" + m, "set_coat", ["method", m], sid)
	if a.has("time_s") and not _near(float(cp.time_s), float(a.time_s)):
		var tt := _num(float(a.time_s), 0) + " s"
		return Guide.make("recubrir_tiempo", "panel", "taller", "Tiempo: %s" % tt, "Pon el tiempo a %s" % tt, tt, "pistola", "recubrir_tiempo", "set_coat", ["time_s", float(a.time_s)], sid)
	# lo que se cubre: sin tocar (−1), el motor ya cubre lo recomendado
	if a.has("cover_mm") and float(cp.get("cover_mm", -1.0)) > 0.0 and not _near(float(cp.cover_mm), float(a.cover_mm)):
		var ct := _num(float(a.cover_mm), 1) + " mm"
		return Guide.make("recubrir_punta", "panel", "taller", "Cuánto de la punta: %s" % ct, "Cubre %s desde la punta" % ct, ct, "pistola", "recubrir_punta", "set_coat", ["cover_mm", float(a.cover_mm)], sid)
	return Guide.make("recubrir", "panel", "taller", "Pulsa aquí: Recubrir (R)", "Pulsa «Recubrir» (R)", "", "pistola", "recubrir", "coat", [], sid)


## Pulir: el abrasivo y el grano del paso y «Pulir» (O).
static func _polish(st: Object, sid: String, a: Dictionary) -> Dictionary:
	var pp: Dictionary = st.get("polish_p")
	var abr := String(a.get("abrasive", ""))
	if abr != "" and String(pp.abrasive) != abr:
		var an := _abrasive_name(abr)
		return Guide.make("pulir_abrasivo:" + abr, "panel", "taller", "Abrasivo de pulir: %s" % an, "Elige la pasta de %s" % an, an, "pulidora", "pulir_abrasivo:" + abr, "set_polish", ["abrasive", abr], sid)
	if a.has("grain_um") and not _near(float(pp.grain_um), float(a.grain_um)):
		var gid := Js.to_fixed(float(a.grain_um), 0)
		var gt := "%s µm" % gid
		return Guide.make("grano:" + gid, "panel", "taller", "Grano: %s" % gt, "Elige el grano de %s" % gt, gt, "pulidora", "grano:" + gid, "set_polish", ["grain_um", float(a.grain_um)], sid)
	return Guide.make("pulir", "panel", "taller", "Pulsa aquí: Pulir (O)", "Pulsa «Pulir» (O): la pasta de %s, %s µm" % [_abrasive_name(String(pp.abrasive)), Js.to_fixed(float(pp.grain_um), 0)], "", "pulidora", "pulir", "polish", [], sid)


## La mesa de soldar: lo recomendado para este metal y su método (el láser pulsado, el micro-TIG o la soldadura fuerte de plata),
## con sus valores, y «Colocar en la mesa» (Q).
static func _weld_setup(st: Object, sid: String, a: Dictionary) -> Dictionary:
	# sin pieza no hay nada que soldar: primero, el tutorial de su receta
	var process := String(st.get("process"))
	var piece: Dictionary = st.call("snap").piece
	if String(piece.get("material", "")) == "" and ForgeData.RECIPES.has(process):
		var pn := String(ForgeData.RECIPES[process].name)
		return Guide.make("tutorial:" + process, "panel", "", "Pulsa aquí: el tutorial de la pieza", "Primero, la pieza: el tutorial «%s»" % pn, pn, "", "tutorial:" + process, "tutorial_goto", [process], sid)
	if not _weld_matches(st, a):
		var vt := weld_values_text(a)
		return Guide.make("soldar_recomendado", "panel", "soldar", "Pulsa aquí: Poner lo recomendado (P)", "Pon lo recomendado (P): %s" % vt, vt, "soldadura", "soldar_recomendado", "apply_recommended", [], sid)
	return Guide.make("soldar_colocar", "panel", "soldar", "Pulsa aquí: Colocar en la mesa (Q)", "Pulsa «Colocar en la mesa» (Q)", "", "soldadura", "soldar_colocar", "weld_prepare", [], sid)


## ¿Están los mandos de la mesa en lo que pide el paso? (El tiempo del micro-TIG va en su mando; el solape, por su valor.)
static func _weld_matches(st: Object, a: Dictionary) -> bool:
	var wp: Dictionary = st.call("weld_params")
	for k: String in a:
		var v: Variant = a[k]
		if k == "overlap":
			if absf(float(wp.overlap) - float(v)) > 0.05:
				return false
		elif v is String:
			if String(wp.get(k, "")) != String(v):
				return false
		elif absf(float(wp.get(k, 0.0)) - float(v)) > 1e-6 * maxf(1.0, absf(float(v))):
			return false
	return true


## Los valores de lo recomendado en la mesa de soldar, en una línea: «Soldadura láser (Nd:YAG pulsado), 51 J, 4 ms, 0,6 mm, argón
## (2 l/min)».
static func weld_values_text(a: Dictionary) -> String:
	var m := String(a.get("method", ""))
	var parts: Array = [String(ClawWeld.METHODS[m].name) if ClawWeld.METHODS.has(m) else m]
	for e: Array in [["energy_j", "J"], ["current_a", "A"], ["pulse_ms", "ms"], ["spot_mm", "mm"], ["temp_c", "°C"], ["gap_mm", "mm de holgura"]]:
		if a.has(String(e[0])):
			parts.append("%s %s" % [Js.js_num_str(float(a[e[0]])), String(e[1])])
	if a.has("gas"):
		parts.append(String(ClawWeld.GAS_NAMES.get(String(a.gas), String(a.gas))).to_lower())
	return ", ".join(parts)


## La costura: dónde mantener pulsado (el primer tramo sin soldar, u de 0 a 1), con cuántos puntos lleva de los que hacen falta.
## Antes, alinear si hace falta.
static func _weld_seam(st: Object, sid: String) -> Dictionary:
	var ws: Dictionary = st.get("forge").weld_state()
	if ws.is_empty() or not bool(ws.get("ready", false)):
		return Guide.make("soldar_colocar", "panel", "soldar", "Pulsa aquí: Colocar en la mesa (Q)", "Pulsa «Colocar en la mesa» (Q)", "", "soldadura", "soldar_colocar", "weld_prepare", [], sid)
	if not bool(ws.get("aligned", false)):
		return Guide.make("soldar_alinear", "panel", "soldar", "Pulsa aquí: Alinear (I)", "Alinea las piezas: «Alinear» (I) o arrastra la punta", "", "costura", "soldar_alinear", "weld_align_pieces", [], sid)
	var segs: Array = ws.get("segments", [])
	var n := segs.size()
	var i := 0
	while i < n and int(segs[i]) > 0:
		i += 1
	var u := (float(mini(i, maxi(n - 1, 0))) + 0.5) / float(maxi(n, 1))
	var progress := "%d de %d puntos" % [int(ws.get("pulses", 0)), int(ws.get("pulsesNeed", 0))]
	var t := Guide.make("costura", "scene", "soldar", "Pulsa aquí: Un punto (J)", "Mantén pulsado sobre la costura y recórrela (o J): %s" % progress, progress, "costura", "soldar_punto", "weld_pulse_next", [], sid)
	t["u"] = u
	return t


static func _near(now: float, want: float) -> bool:
	return absf(now - want) <= maxf(1e-9, SLIDER_TOL * absf(want))


static func _num(x: float, d: int) -> String:
	return Js.to_fixed(x, d)


static func _lower_first(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1)
