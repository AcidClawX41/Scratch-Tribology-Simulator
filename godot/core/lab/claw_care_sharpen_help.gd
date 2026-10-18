## Tribología biológica · cetrería: qué herramienta afila y cómo va la punta (unidad 5s; petición 60 de Eric: «¿cuáles
## sirven para afilar más la garra? Lo único que he hecho ha sido recortarla; yo la quiero hacer más afilada»). Funciones
## puras, sin nodos ni estado: leen el motor (una ClawCare, solo por sus funciones públicas) y la mano (la de
## ClawCareState.hand_view: herramienta, fuerza, ángulo y rpm) y no cambian nada. Sin física nueva:
##   - purpose(id): para qué sirve cada herramienta de la bandeja en una línea («acorta», «quita largo y da forma», «afila la
##     punta», «pule»…) y si afila: con control (la lima fina y la de diamante fina) o tan deprisa que se pasa (el torno y la
##     amoladora), con su fuente.
##   - meter(care, hand): el medidor de la punta: roma · natural · afilada · aguja frente a la banda buena (×0,5 a ×2 la
##     natural, CareData.MARGINS; el borde de la aguja, el del motor: aguanta de lado menos de la cuarta parte que la natural,
##     «Demasiado fina» en ClawCare.shape), la flecha de dónde está y cuántas pasadas de referencia faltan con la mano de
##     ahora. Las pasadas salen de la misma geometría que ClawCare.file (la faceta cónica, el corte de frente y el adelgazado
##     de los flancos; los conos de la faceta de un mismo ángulo están unos dentro de otros, así que k pasadas iguales dejan
##     lo mismo que una de k veces el volumen) y del arranque del motor (ClawCare.removal_mm3).
##   - lupa(care, snap): la punta a escala de micras, para la lupa y para la malla: su perfil cerca del vértice (el del motor,
##     con la esfera de la punta de su radio o la cara plana), la punta natural para comparar, la faceta (dónde empieza y su
##     ángulo), si está mellada y la barra de escala.
##   - advice(care, hand): el aviso para afilar después de recortar (o con una herramienta o un ángulo que no afilan): la
##     herramienta que muerde el material de la punta y el ángulo bueno de esta garra, con su fuente.
## Lo que es solo presentación va marcado (la pasada de referencia, los extremos del medidor, la barra de escala).
## Unidades: mm (radios de punta en µm) · N · grados · mm³ · s.
## Uso: const SharpenHelp = preload("res://core/lab/claw_care_sharpen_help.gd")
##      var h := SharpenHelp.view(state.care, state.hand_view(), state.care.snapshot())   # { meter, lupa, advice }
extends RefCounted

const ClawCare = preload("res://core/lab/claw_care.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Abrasion = preload("res://core/shared/abrasion.gd")

## La pasada de referencia del medidor (presentación, no un dato): 1 cm de lima apretando con la fuerza de la mano, de la base
## a la punta; con una giratoria, un toque de 1 s.
const REF_PASS_MM := 10.0
const REF_TOUCH_S := 1.0
## Extremos del medidor (veces el radio natural, en escala logarítmica; dibujo): de una punta de grano de lija a la cara de un
## corte grueso.
const SCALE_MIN := 0.02
const SCALE_MAX := 20.0
## Una aguja: aguanta de lado menos de esta fracción que la natural («Demasiado fina» de ClawCare.shape; la carga que aguanta
## crece con R², así que con el ángulo de la garra es la mitad del radio: ClawSharpness, Pattrick et al. 2018).
const NEEDLE_STRENGTH := 0.25
## Pasadas que se cuentan como mucho (más ya no es «unas pocas»: se dice que son muchas).
const PASSES_CAP := 99
## El ángulo bueno para afilar: más abierto que el de la garra (con el de la garra o menos, la lima solo adelgaza los flancos:
## ClawCare.file, `angle <= tip_alpha + 1`), sin pasar del margen del informe (CareData.MARGINS.facet_deg: más, «facetada»):
## de la garra + la mitad del margen a la garra + el margen. La mitad es una elección del consejo (una faceta más corta).
const GOOD_ANGLE_FROM := 0.5

const ZONE_NAMES := { "roma": "Roma", "natural": "Natural", "afilada": "Afilada", "aguja": "Aguja" }
const ZONE_TONE := { "roma": "aviso", "natural": "bien", "afilada": "bien", "aguja": "mal" }
## Los papeles de las herramientas, en las palabras de la tarjeta.
const ROLE_TEXT := {
	"acorta": "acorta", "forma": "quita largo y da forma", "afila": "afila la punta", "pule": "pule", "cura": "cura",
	"prepara": "prepara", "pieza": "coloca la pieza",
}
## Para qué sirve cada herramienta de la bandeja (también las que no están en CareData.TOOLS: el agua, la gasa, el alcohol y la
## espátula): role (ROLE_TEXT), line (una línea), sharpens («si»: afila con control, poco en cada pasada; «rapido»: afila en un
## instante y se pasa enseguida; «»: no es para afilar) y su fuente. Presentación con las fuentes de cada herramienta: lo que
## hace cada una lo calcula el motor.
const SRC_COPING := CareData.SRC_SAMOUR + ", p. 927 (las garras crecidas se recortan con un cortaúñas de guillotina y se les da forma con una cuchilla y limas)"
const SRC_EDGE := "la punta más fina que deja una herramienta es la de su arista o su grano: " + String(CareData.TOOTH_GEOMETRY.source) + "; " + String(CareData.GRAIN_GEOMETRY.source)
const PURPOSES := {
	"guillotina": { "role": "acorta", "line": "acorta de un corte: deja la punta plana y roma", "sharpens": "", "source": SRC_COPING },
	"tijera": { "role": "acorta", "line": "acorta, pero aprieta por los dos lados y aplasta más", "sharpens": "", "source": SRC_COPING },
	"tenaza": { "role": "acorta", "line": "acorta las garras grandes que no caben en un cortaúñas", "sharpens": "", "source": CareData.SRC_CATTALES },
	"lima_bastarda": { "role": "forma", "line": "quita largo y da forma: mucho en cada pasada", "sharpens": "", "source": CareData.SRC_DIN8349 + "; " + CareData.SRC_NICHOLSON },
	"lima_entrefina": { "role": "forma", "line": "quita largo y da forma, con rayas más finas que la gruesa", "sharpens": "", "source": CareData.SRC_DIN8349 },
	"lima_fina": { "role": "afila", "line": "afila la punta: una faceta corta alrededor del vértice, poco en cada pasada", "sharpens": "si", "source": ClawSharpness.SRC_PATTRICK + "; " + SRC_EDGE },
	"lima_diamante_gruesa": { "role": "forma", "line": "quita largo y da forma en lo duro (gemas, cerámica, metal duro)", "sharpens": "", "source": CareData.SRC_DMT + "; " + CareData.SRC_FILE_TEST },
	"lima_diamante_fina": { "role": "afila", "line": "afila la punta, también en lo duro, y deja la superficie lisa", "sharpens": "si", "source": CareData.SRC_DMT + "; " + ClawSharpness.SRC_PATTRICK + "; " + SRC_EDGE },
	"lija_p180": { "role": "pule", "line": "alisa las rayas de la lima", "sharpens": "", "source": CareData.SRC_KLINGSPOR },
	"lija_p240": { "role": "pule", "line": "pule: la superficie más fina de las de mano", "sharpens": "", "source": CareData.SRC_KLINGSPOR },
	"torno": { "role": "forma", "line": "quita largo muy deprisa; afila en un instante y se pasa enseguida", "sharpens": "rapido", "source": CareData.SRC_DREMEL_7300 + "; " + CareData.SRC_DREMEL_GUIDE },
	"amoladora": { "role": "forma", "line": "como el torno, apoyada a 45° en su protector: afila en un instante y deja la faceta abierta", "sharpens": "rapido", "source": CareData.SRC_DREMEL_7760 + "; " + CareData.SRC_DREMEL_GUIDE },
	"agua": { "role": "prepara", "line": "remoja: ablanda la garra antes de cortarla", "sharpens": "", "source": CareData.SRC_AAD },
	"presion": { "role": "cura", "line": "aprieta la herida: sin nada, para la sangre en 5-10 minutos", "sharpens": "", "source": CareData.SRC_VCA },
	"hemostatico": { "role": "cura", "line": "para la sangre en segundos, con presión", "sharpens": "", "source": CareData.SRC_MSD + "; " + CareData.SRC_DREMEL_GUIDE },
	"nitrato_plata": { "role": "cura", "line": "para la sangre, pero escuece más", "sharpens": "", "source": CareData.SRC_SAMOUR + "; " + CareData.SRC_COAKLEY },
	"clorhexidina": { "role": "cura", "line": "desinfecta la herida sin retrasar la cicatrización", "sharpens": "", "source": CareData.SRC_LOZIER },
	"crema": { "role": "cura", "line": "hidrata la garra al terminar", "sharpens": "", "source": CareData.SRC_SAMOUR + ", p. 927" },
	"metacrilato": { "role": "cura", "line": "reconstruye una garra rota, de forma provisional", "sharpens": "", "source": CareData.SRC_SAMOUR },
	"alcohol": { "role": "pieza", "line": "limpia y desengrasa donde va a pegar la pieza", "sharpens": "", "source": CareData.SRC_LOCTITE_401_TDS },
	"espatula": { "role": "pieza", "line": "pone el acrílico o la resina y quita lo que rebosa", "sharpens": "", "source": CareData.SRC_VERACRIL },
}
## Las herramientas que afilan con control, por orden de preferencia: la primera que muerde el material de la punta es la que se
## aconseja.
const SHARPENERS := ["lima_fina", "lima_diamante_fina"]


# ════════════════════════════════ Para qué sirve cada herramienta ════════════════════════════════

## Para qué sirve una herramienta de la bandeja: { id, role, roleText, line, sharpens, source, edgeUm (la punta más fina que
## deja nueva: el radio de su arista o de su grano; null si no lima) }. {} si no la conoce.
static func purpose(id: String) -> Dictionary:
	if not PURPOSES.has(id):
		return {}
	var p: Dictionary = PURPOSES[id]
	var td := CareData.tool(id)
	var edge: Variant = null
	if String(td.get("kind", "")) in ["lima", "torno"]:
		edge = float((CareData.TOOTH_GEOMETRY if String(td.get("element", "grano")) == "diente" else CareData.GRAIN_GEOMETRY).tip_um)
	return { "id": id, "role": String(p.role), "roleText": String(ROLE_TEXT[String(p.role)]), "line": String(p.line),
		"sharpens": String(p.sharpens), "source": String(p.source), "edgeUm": edge }


## ¿Es de limar (una lima, una lija, el torno o la amoladora)?
static func is_filing(id: String) -> bool:
	return String(CareData.tool(id).get("kind", "")) in ["lima", "torno"]


# ════════════════════════════════ El medidor ════════════════════════════════

## Posición (0-1) de un radio de punta (veces el natural) en el medidor, en escala logarítmica entre SCALE_MIN y SCALE_MAX.
static func pos_of(ratio: float) -> float:
	var r := clampf(ratio, SCALE_MIN, SCALE_MAX)
	return clampf((V8.js_log(r) - V8.js_log(SCALE_MIN)) / (V8.js_log(SCALE_MAX) - V8.js_log(SCALE_MIN)), 0.0, 1.0)


## El radio (veces el natural) por debajo del cual la punta es una aguja con el ángulo de punta de ahora: donde lo que aguanta
## de lado baja a NEEDLE_STRENGTH de lo que aguanta la natural (como crece con R², r = r0·√(0,25·F(r0, α0)/F(r0, α))). Con el
## ángulo de la garra, ×0,5: el borde de abajo de la banda del informe (CareData.MARGINS.tip_ratio_lo).
static func needle_ratio(care: ClawCare) -> float:
	var ts := care.tip_state()
	var r0 := float(ts.naturalUm)
	var c0 := ClawSharpness.chip_load_n(ClawSharpness.tip_of(r0, float(ts.naturalAlphaDeg)), 1.0)
	var c1 := ClawSharpness.chip_load_n(ClawSharpness.tip_of(r0, float(ts.alphaDeg)), 1.0)
	if not (c0 > 0.0) or not (c1 > 0.0) or is_inf(c0) or is_inf(c1):
		return float(CareData.MARGINS.tip_ratio_lo)
	return sqrt(NEEDLE_STRENGTH * c0 / c1)


## La zona de una punta: «aguja» (aguanta de lado menos de NEEDLE_STRENGTH que la natural: la «Demasiado fina» del motor; sin
## datos de resistencia, más fina que el borde de la aguja), «roma» (más del doble del radio natural, CareData.MARGINS),
## «afilada» (más fina que la natural) o «natural».
static func zone_of(ratio: float, strength_ratio: Variant, needle: float) -> String:
	if strength_ratio != null:
		if float(strength_ratio) < NEEDLE_STRENGTH:
			return "aguja"
	elif ratio < needle:
		return "aguja"
	if ratio > float(CareData.MARGINS.tip_ratio_hi):
		return "roma"
	return "afilada" if ratio < 1.0 else "natural"


## El medidor de la punta (lo que pinta la interfaz; los números, del motor): { zone, zoneName, tone, ratio, tipRadiusUm,
## naturalUm, strengthRatio, alphaDeg, naturalAlphaDeg, needleRatio, bandLo, bandHi, pos, bandPos, zones (cada zona con su
## tramo del medidor), marks, passes (passes()), text, source }.
## (cierre de la 5s, Eric: «más resistentes si son romas, o más afiladas y punzantes o desgarrantes si están muy afiladas
## como agujas, pero pueden partirse con más facilidad dependiendo del material»). Qué hace la punta según su material:
##   - de lado (ClawCare.tip_state: el voladizo de claw_sharpness.gd con la resistencia de su material, claw_fracture.gd):
##     la queratina se mella o se deshilacha, los metales se doblan y los frágiles se descascarillan o se parten;
##   - al pinchar (Hokkirigawa y Kato 1988): el grado de penetración Dp = h/a contra la uña del banco (la prueba de la punta,
##     ClawCare.PROBE_TARGET con PROBE_FORCE_N): a = √(F/(π·H)) y h, la hondura de la punta esfero-cónica con ese radio de
##     contacto; arado (< 0,1), cuña o corte (> 0,2): la aguja corta y desgarra, la roma empuja y ara.
const MATERIAL_VERBS := {
	"queratina": "se mella o se deshilacha", "ductil": "se dobla", "fragil": "se descascarilla o se parte",
	"sin_datos": "sin datos de cómo se rompe",
}
const MODE_TEXT := { "corte": "corta y desgarra", "cuña": "entra en cuña", "arado": "empuja y ara, sin cortar" }
const SRC_HOKKIRIGAWA := "Hokkirigawa K, Kato K (1988). An experimental and theoretical investigation of ploughing, cutting and wedge formation during abrasive wear. Tribol. Int. 21:51-57 (grado de penetración Dp = h/a: arado por debajo de 0,1, cuña hasta 0,2 y corte por encima)"


## { behavior, verb, materialName, lateralN (N), strengthRatio, strengthMPa, kind, dp, mode, modeText, text }.
static func tip_character(care: ClawCare, ts_in: Dictionary = {}) -> Dictionary:
	var ts := ts_in if not ts_in.is_empty() else care.tip_state()
	var tm := care.tip_material()
	var target: Dictionary = ClawCare.Catalog.find_by_id(ClawCare.Catalog.TARGETS, ClawCare.PROBE_TARGET)
	var h_mpa := float(target.hv) * Contact.HV_MPA
	var tip := ClawSharpness.tip_of(float(ts.tipRadiusUm), float(ts.alphaDeg))
	var a := sqrt(float(ClawCare.PROBE_FORCE_N) / (PI * h_mpa))
	var dp := Contact.depth_for_radius(tip, a) / a
	var mode := String(Abrasion.abrasion_mode(dp).absMode)
	var beh := String(tm.behavior)
	var st: Variant = tm.strength
	var out := {
		"behavior": beh, "verb": String(MATERIAL_VERBS.get(beh, MATERIAL_VERBS.sin_datos)), "materialName": String(tm.name),
		"lateralN": ts.lateralN, "strengthRatio": ts.strengthRatio, "strengthMPa": float((st as Dictionary).value) if st is Dictionary else null,
		"kind": String((st as Dictionary).get("kind", "")) if st is Dictionary else "", "dp": dp, "mode": mode,
		"modeText": String(MODE_TEXT.get(mode, mode)),
	}
	var side := ""
	if ts.lateralN != null:
		var mn := float(ts.lateralN) * 1000.0
		side = "De lado aguanta %s; si pasa de ahí, %s" % [_force_text(mn), String(out.verb)]
	else:
		side = "De lado: %s" % String(out.verb)
	var mat := "la queratina" if beh == "queratina" else String(tm.name).to_lower()
	out["text"] = "%s (%s). Al pinchar una uña con %s N, %s (Dp %s)." % [side, mat, Js.to_fixed(float(ClawCare.PROBE_FORCE_N), 1),
		String(out.modeText), Js.to_fixed(dp, 2)]
	return out


static func _force_text(mn: float) -> String:
	if mn >= 1000.0:
		return "%s N" % Js.to_fixed(mn / 1000.0, 1)
	return "%s mN" % (Js.to_fixed(mn, 1) if mn < 10.0 else Js.to_fixed(mn, 0))


static func meter(care: ClawCare, hand: Dictionary = {}) -> Dictionary:
	var ts := care.tip_state()
	var ratio := float(ts.ratio)
	var needle := needle_ratio(care)
	var hi := float(CareData.MARGINS.tip_ratio_hi)
	var zone := zone_of(ratio, ts.strengthRatio, needle)
	var ps := passes(care, hand)
	var out := {
		"zone": zone, "zoneName": String(ZONE_NAMES[zone]), "tone": String(ZONE_TONE[zone]), "ratio": ratio,
		"tipRadiusUm": float(ts.tipRadiusUm), "naturalUm": float(ts.naturalUm), "strengthRatio": ts.strengthRatio,
		"alphaDeg": float(ts.alphaDeg), "naturalAlphaDeg": float(ts.naturalAlphaDeg), "needleRatio": needle,
		"bandLo": needle, "bandHi": hi, "pos": pos_of(ratio), "bandPos": [pos_of(needle), pos_of(hi)],
		"zones": [
			{ "id": "aguja", "from": 0.0, "to": pos_of(needle) }, { "id": "afilada", "from": pos_of(needle), "to": pos_of(1.0) },
			{ "id": "natural", "from": pos_of(1.0), "to": pos_of(hi) }, { "id": "roma", "from": pos_of(hi), "to": 1.0 },
		],
		"marks": [
			{ "ratio": needle, "pos": pos_of(needle), "label": "×%s" % Js.to_fixed(needle, 1) },
			{ "ratio": 1.0, "pos": pos_of(1.0), "label": "×1" },
			{ "ratio": hi, "pos": pos_of(hi), "label": "×%s" % Js.to_fixed(hi, 0) },
		],
		"passes": ps,
		"character": tip_character(care, ts),
		"source": String(CareData.MARGINS.source) + "; " + ClawSharpness.SRC_PATTRICK + "; " + SRC_HOKKIRIGAWA,
	}
	out["text"] = _meter_text(out, ps)
	return out


static func _meter_text(m: Dictionary, ps: Dictionary) -> String:
	var head := "%s: punta de %s µm, ×%s de la natural (%s µm)" % [String(m.zoneName), _um(float(m.tipRadiusUm)), _ratio_text(float(m.ratio)),
		_um(float(m.naturalUm))]
	if m.strengthRatio != null and String(m.zone) == "aguja":
		head += "; aguanta de lado el %s %% de la natural" % Js.to_fixed(float(m.strengthRatio) * 100.0, 0)
	var how := _cap(String(ps.get("text", "")))
	return head + (". " + how if how != "" else ".")


## Un radio (µm) con las cifras que se leen: 5 · 47 · 113 · 1292.
static func _um(x: float) -> String:
	return Js.to_fixed(x, 1) if x < 10.0 else Js.to_fixed(x, 0)


## Veces la natural, con las cifras que se leen: 0.04 · 0.5 · 1.9 · 11.
static func _ratio_text(r: float) -> String:
	if r < 0.1:
		return Js.to_fixed(r, 2)
	return Js.to_fixed(r, 1) if r < 10.0 else Js.to_fixed(r, 0)


# ════════════════════════════════ Cuántas pasadas faltan ════════════════════════════════

## Lo que quita una pasada de referencia con la herramienta tool_id, la fuerza force_n y, si gira, rpm, en la punta de ahora:
## el arranque del motor (ClawCare.removal_mm3, con la herramienta como está: ClawCareKit.worn_tool) con el contacto de la
## punta de ClawCare.file (el ancho de la garra a 1 mm del vértice). La pasada en régimen dúctil (en un material frágil por
## encima de la hondura de Bifano el motor arranca algo más: el número de pasadas queda por arriba).
## { mm3, travelMm, seconds (giratorias: lo que dura el toque), edgeUm (el radio de los filos ahora) }.
static func pass_volume(care: ClawCare, tool_id: String, force_n: float, rpm: float = 0.0) -> Dictionary:
	var td := CareData.tool(tool_id)
	if td.is_empty() or not is_filing(tool_id):
		return { "mm3": 0.0, "travelMm": 0.0, "seconds": 0.0, "edgeUm": 0.0 }
	var tw := care.kit().worn_tool(td)
	var apex := care.apex_mm()
	var w_tip := 2.0 * maxf(care.radius_at(apex - 1.0), 0.1)
	var m := care.material_at(maxf(apex - 0.5 * ClawCare.STATION_MM, 0.0))
	var hum := String(care.setup().get("humidity", "natural"))
	var h := ClawCare.hardness_mpa(float(m.hv), hum, bool(m.reforged))
	var rotary := String(td.kind) == "torno"
	var travel := REF_PASS_MM
	var secs := 0.0
	if rotary:
		var n := rpm if rpm > 0.0 else float(td.get("rpm", 0.0))
		secs = REF_TOUCH_S
		travel = ClawCare.surface_speed_ms(float(td.drum_mm), n) * 1000.0 * secs
	var dv := ClawCare.removal_mm3(tw, maxf(force_n, 0.0), travel, w_tip, w_tip, float(m.hv), h, false)
	return { "mm3": dv, "travelMm": travel, "seconds": secs, "edgeUm": care.kit().edge_um(td) }


## Los radios del motor en sus estaciones (cada ClawCare.STATION_MM) de s_from a la punta: { s, r } (el último, la estación de
## la punta o antes; ClawCare.radius_at en cada estación da el de su perfil).
static func _stations(care: ClawCare, s_from: float) -> Dictionary:
	var ss := PackedFloat64Array()
	var rs := PackedFloat64Array()
	var st := ClawCare.STATION_MM
	var apex := care.apex_mm()
	var i_top := int(floor(apex / st + 1e-9))
	for i in range(maxi(int(floor(s_from / st)), 0), i_top + 1):
		var s := float(i) * st
		ss.append(s)
		rs.append(care.radius_at(s))
	return { "s": ss, "r": rs }


## Volumen (mm³) que arranca una faceta cónica con el vértice en sc y tan θ = t, sobre las estaciones st (la cuenta de
## ClawCare._facet: solo donde el cono es más estrecho que la garra).
static func facet_volume(st: Dictionary, sc: float, t: float) -> float:
	var ss: PackedFloat64Array = st.s
	var rs: PackedFloat64Array = st.r
	var v := 0.0
	for i in ss.size():
		var rc := maxf((sc - ss[i]) * t, 0.0)
		if rs[i] > rc:
			v += PI * (rs[i] * rs[i] - rc * rc) * ClawCare.STATION_MM
	return v


## Dónde queda el vértice del cono de la faceta (mm desde la base) después de arrancar dv con tan θ = t: la bisección de
## ClawCare._facet (V(sc) baja con sc; como mucho, lo que queda de garra en las estaciones st).
static func facet_sc(st: Dictionary, apex: float, flat: float, t: float, dv: float) -> float:
	var ss: PackedFloat64Array = st.s
	var rs: PackedFloat64Array = st.r
	var hi := apex + flat / t
	for i in ss.size():
		hi = maxf(hi, ss[i] + rs[i] / t)
	var lo := ss[0] if ss.size() > 0 else 0.0
	var target := minf(dv, facet_volume(st, lo, t))
	for it in 50:
		var mid := 0.5 * (lo + hi)
		if facet_volume(st, mid, t) > target:
			lo = mid
		else:
			hi = mid
	return hi


## Volumen (mm³) que hay que limar de frente desde la punta hasta que la cara mida rho (mm) de radio: el corte de
## ClawCare._truncate_volume (la sección en cada paso por su largo). INF si ni en la base llega.
static func frontal_volume(care: ClawCare, rho: float) -> float:
	var s := care.apex_mm()
	var v := 0.0
	var st := ClawCare.STATION_MM
	while s > 0.0:
		var r := care.radius_at(s)
		if r >= rho:
			return v
		var ds := minf(st, s)
		v += PI * r * r * ds
		s -= ds
	return INF


## Cuántas pasadas de referencia (pass_volume) faltan con la mano hand ({ tool, force_n, angle_deg, rpm }) para llevar la punta a
## la banda buena, con la geometría de ClawCare.file:
##   - en faceta (el ángulo más abierto que la punta y de menos de ClawCare.TRUNCATE_DEG): la cara plana se cierra con el cono;
##     cuando se cierra del todo, la punta queda con el radio de los filos de la herramienta;
##   - de frente (≥ TRUNCATE_DEG): acorta y deja una cara del radio de la garra donde corta;
##   - con el ángulo de la punta o menos: adelgaza los flancos de los últimos 3 mm y la cara pierde la misma sección.
## { mode («faceta» | «frente» | «flanco» | «no_lima» | «no_muerde»), unit («pasada» | «toque»), mm3 (por pasada), toBand,
##   toNatural, toClose (pasadas hasta la banda, hasta la natural y hasta que la faceta cierra la cara: -1 si no aplica; tope
##   PASSES_CAP), secondsToBand, secondsToClose (giratorias), edgeUm, closeRatio (cómo queda la punta al cerrarse la faceta),
##   overshoot (la pasada que llega a la banda ya la deja como una aguja), text }.
static func passes(care: ClawCare, hand: Dictionary) -> Dictionary:
	var tool_id := String(hand.get("tool", ""))
	var out := { "mode": "no_lima", "unit": "pasada", "mm3": 0.0, "toBand": -1, "toNatural": -1, "toClose": -1, "secondsToBand": -1.0,
		"secondsToClose": -1.0, "edgeUm": 0.0, "closeRatio": -1.0, "overshoot": false, "text": "" }
	var ts := care.tip_state()
	var r0 := float(ts.naturalUm) / 1000.0
	var ratio := float(ts.ratio)
	var needle := needle_ratio(care)
	var hi := float(CareData.MARGINS.tip_ratio_hi)
	var zone := zone_of(ratio, ts.strengthRatio, needle)
	var dmg: Dictionary = care.broken_state()
	if bool(dmg.broken):
		# (5v) la garra rota: la punta que se lee es la del muñón
		out["mode"] = "rota"
		out["text"] = "Reconstruida: la punta que se lee es la del muñón (el metacrilato es provisional hasta que crezca)." if bool(dmg.repaired) \
			else "La garra está rota: primero repararla (parar la sangre, desinfectar y reconstruirla o reforjarla); la punta que se lee es la del muñón."
		return out
	if tool_id == "" or not is_filing(tool_id):
		out["text"] = _no_file_text(zone, tool_id)
		return out
	var td := CareData.tool(tool_id)
	var rotary := String(td.kind) == "torno"
	out["unit"] = "toque" if rotary else "pasada"
	var pv := pass_volume(care, tool_id, float(hand.get("force_n", 3.0)), float(hand.get("rpm", 0.0)))
	var dv := float(pv.mm3)
	var edge := float(pv.edgeUm) / 1000.0
	out["mm3"] = dv
	out["edgeUm"] = float(pv.edgeUm)
	out["closeRatio"] = edge / r0 if r0 > 0.0 else -1.0
	if not (dv > 0.0):
		out["mode"] = "no_muerde"
		out["text"] = "%s no muerde la punta: no la afila." % _cap(_tool_name(tool_id))
		return out
	var angle := Contact.clamp_js(float(hand.get("angle_deg", 45.0)), 1.0, 90.0)
	var a := care.apex_mm()
	var f := float(ts.flatMm)
	var tip_mm := float(ts.tipRadiusUm) / 1000.0
	var v_band := -1.0
	var v_nat := -1.0
	var v_close := -1.0
	if angle >= ClawCare.TRUNCATE_DEG:
		out["mode"] = "frente"
		# de frente la cara crece: hasta salir de la aguja (el borde de abajo de la banda) y hasta pasarse de roma
		if tip_mm < needle * r0:
			v_band = frontal_volume(care, needle * r0)
		v_nat = frontal_volume(care, r0) if tip_mm < r0 else -1.0
		v_close = frontal_volume(care, hi * r0) if tip_mm <= hi * r0 else 0.0
	else:
		# la cara de la punta pierde la misma sección que cada estación de los últimos 3 mm (ClawCare._thin_flank)
		var st := ClawCare.STATION_MM
		var cnt := maxi(int(ceil(a / st)) - int(floor(maxf(a - 3.0, 0.0) / st)) + 1, 1)
		var per_area := float(cnt) * st * PI
		var first := 0.0
		var f1 := f
		if angle > care.tip_alpha_deg() + 1.0:
			# la primera pasada (o el primer trozo de un toque, ClawCare.ROTARY_CHUNK_S) talla la faceta cónica; desde ahí la
			# punta va a ese ángulo y las siguientes, con el mismo, adelgazan los flancos (ClawCare.file)
			out["mode"] = "faceta"
			first = dv * (ClawCare.ROTARY_CHUNK_S / REF_TOUCH_S if rotary else 1.0)
			var t := V8.js_tan(angle * Contact.DEG)
			var base_r := float(care.tip_geometry().get("amax", 1.0))
			var stn := _stations(care, a - base_r / t - ClawCare.STATION_MM)
			var sc := facet_sc(stn, a, f, t, first)
			f1 = minf(f, (sc - a) * t) if sc > a else 0.0
			# sin cara plana, la punta ya es un vértice: lo primero que quite la faceta la deja con el radio de los filos
			if f <= 0.0:
				f1 = 0.0
			if f > hi * r0:
				v_band = facet_volume(stn, a + hi * r0 / t, t)
			if f > r0:
				v_nat = facet_volume(stn, a + r0 / t, t)
			v_close = facet_volume(stn, a, t) if f > 0.0 else 0.0
		else:
			out["mode"] = "flanco"
		# lo que haga falta más allá de la primera pasada, adelgazando los flancos
		var targets := [[hi * r0, "band"], [r0, "nat"], [0.0, "close"]]
		for tg: Array in targets:
			var rho := float(tg[0])
			if f <= rho and rho > 0.0:
				continue
			var v := -1.0
			if String(out.mode) == "faceta":
				var v_facet := v_band if String(tg[1]) == "band" else (v_nat if String(tg[1]) == "nat" else v_close)
				v = v_facet if v_facet >= 0.0 and v_facet <= first else first + maxf(f1 * f1 - rho * rho, 0.0) * per_area
			else:
				v = maxf(f * f - rho * rho, 0.0) * per_area
			match String(tg[1]):
				"band":
					v_band = v
				"nat":
					v_nat = v
				"close":
					v_close = v
	out["toBand"] = _count(v_band, dv)
	out["toNatural"] = _count(v_nat, dv)
	out["toClose"] = _count(v_close, dv)
	if rotary:
		out["secondsToBand"] = v_band / dv * REF_TOUCH_S if v_band >= 0.0 else -1.0
		out["secondsToClose"] = v_close / dv * REF_TOUCH_S if v_close >= 0.0 else -1.0
	# se pasa: la pasada que llega a la banda (o la siguiente, si ya está) cierra la cara y deja la punta con el radio de los filos
	var needle_after := edge < needle * r0
	if String(out.mode) in ["faceta", "flanco"] and needle_after and v_close >= 0.0:
		var reach := maxf(v_band, 0.0)
		out["overshoot"] = ceilf(reach / dv + 1e-9) * dv >= v_close - 1e-12 if reach > 0.0 else dv >= v_close - 1e-12
	out["text"] = _passes_text(out, zone, tool_id, angle, care)
	return out


## Pasadas enteras para quitar v con pasadas de dv: -1 si no hace falta llegar (v < 0) o no aplica; PASSES_CAP como mucho.
static func _count(v: float, dv: float) -> int:
	if v < 0.0 or not (dv > 0.0):
		return -1
	if is_inf(v):
		return PASSES_CAP
	return mini(int(ceil(v / dv - 1e-9)), PASSES_CAP)


static func _passes_text(p: Dictionary, zone: String, tool_id: String, angle: float, care: ClawCare) -> String:
	var nm := _tool_name(tool_id)
	var unit := String(p.unit)
	var rotary := unit == "toque"
	var lo_hi := good_angles(care)
	match String(p.mode):
		"frente":
			if zone == "aguja":
				return "De frente le deja una cara: %s para salir de la aguja." % _count_text(int(p.toBand), float(p.secondsToBand), rotary)
			if zone == "roma":
				return "De frente acorta y la deja aún más roma: para afilar, gira a %s-%s° (A/D)." % [Js.to_fixed(float(lo_hi[0]), 0), Js.to_fixed(float(lo_hi[1]), 0)]
			return "De frente acorta y deja la cara más ancha: %s y ya es roma." % _count_text(int(p.toClose), float(p.secondsToClose), rotary)
		"flanco", "faceta":
			var lead := ""
			if String(p.mode) == "flanco" and angle < care.tip_alpha_deg() - 1.0:
				lead = "A %s°, más tumbada que la punta (%s°), solo adelgaza los flancos; " % [Js.to_fixed(angle, 0), Js.to_fixed(care.tip_alpha_deg(), 0)]
			if zone == "aguja":
				return lead + "ya es una aguja: limar más la deja igual de fina y más corta."
			if zone == "roma":
				var n := int(p.toBand)
				var txt := lead + "con %s, %s para la banda buena" % [nm, _count_text(n, float(p.secondsToBand), rotary)]
				if n >= PASSES_CAP:
					txt += " (muchas: %s quita más; o corta menos la próxima vez)" % ("la lima gruesa" if not rotary else "baja la presión y da toques")
				if bool(p.overshoot):
					txt += "; ojo: %s cierra la cara y la deja como una aguja (×%s)" % ["ese toque" if rotary else "esa misma pasada", _ratio_text(float(p.closeRatio))]
				return txt + "."
			if bool(p.overshoot):
				return lead + "en la banda buena: para aquí. %s más la deja como una aguja (×%s)." % [_cap("un toque" if rotary else "una pasada"), _ratio_text(float(p.closeRatio))]
			return lead + "en la banda buena: puedes parar (%s hasta cerrar la cara)." % _count_text(int(p.toClose), float(p.secondsToClose), rotary)
	return ""


## «unas 3 pasadas de 1 cm» · «menos de 1 pasada» · «un toque de 0.04 s».
static func _count_text(n: int, secs: float, rotary: bool) -> String:
	if rotary:
		if secs < 0.0:
			return "unos toques"
		if secs < 0.1:
			return "un toque de %s s" % Js.to_fixed(secs, 2)
		return "%s s de toque" % Js.to_fixed(secs, 1)
	if n < 0:
		return "unas pasadas"
	if n <= 1:
		return "1 pasada de 1 cm"
	if n >= PASSES_CAP:
		return "más de %d pasadas de 1 cm" % PASSES_CAP
	return "unas %d pasadas de 1 cm" % n


static func _no_file_text(zone: String, tool_id: String) -> String:
	var td := CareData.tool(tool_id)
	if String(td.get("kind", "")) == "cortaunas":
		return "El cortaúñas acorta y deja la punta plana: para afilar, la lima fina." if zone != "aguja" else ""
	if zone == "roma":
		return "Para afilar, coge la lima fina (tecla 2)."
	return ""


static func _tool_name(id: String) -> String:
	var short := {
		"lima_bastarda": "la lima gruesa", "lima_entrefina": "la lima entrefina", "lima_fina": "la lima fina",
		"lima_diamante_gruesa": "la lima de diamante gruesa", "lima_diamante_fina": "la lima de diamante fina",
		"lija_p180": "la lija P180", "lija_p240": "la lija P240", "torno": "el torno", "amoladora": "la amoladora",
	}
	return String(short.get(id, String(CareData.tool(id).get("name", id)).to_lower()))


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


# ════════════════════════════════ El aviso para afilar ════════════════════════════════

## El ángulo bueno para afilar esta garra (grados): [la garra + GOOD_ANGLE_FROM·margen, la garra + margen] (CareData.MARGINS).
static func good_angles(care: ClawCare) -> Array:
	var a0 := float(care.tip_state().naturalAlphaDeg)
	var m := float(CareData.MARGINS.facet_deg)
	return [a0 + GOOD_ANGLE_FROM * m, a0 + m]


## Las herramientas que afilan con control y muerden el material de la punta (ClawCare.bites_at, la eficacia de file()).
static func sharpeners_for(care: ClawCare) -> Array:
	var s := maxf(care.apex_mm() - 0.5 * ClawCare.STATION_MM, 0.0)
	var out: Array = []
	for id: String in SHARPENERS:
		if care.bites_at(id, s) >= 0.5:
			out.append(id)
	return out


## El aviso para afilar: sale si la punta está roma y tiene una cara plana (recortada, o limada de frente), o si la mano lleva
## una herramienta que acorta. { show, title, text, fix (lo que hay que cambiar de la mano, o «»), tools, angleLo, angleHi,
## alphaDeg, source }.
static func advice(care: ClawCare, hand: Dictionary = {}) -> Dictionary:
	var ts := care.tip_state()
	var ratio := float(ts.ratio)
	var zone := zone_of(ratio, ts.strengthRatio, needle_ratio(care))
	var ang := good_angles(care)
	var tools := sharpeners_for(care)
	var a0 := float(ts.naturalAlphaDeg)
	var src := ClawSharpness.SRC_PATTRICK + "; " + String(CareData.MARGINS.source) + "; " + CareData.SRC_AAD + "; " + CareData.SRC_NICHOLSON + "; " + CareData.SRC_DREMEL_GUIDE + "; " + SRC_EDGE
	var out := { "show": false, "title": "Para afilar", "text": "", "fix": "", "tools": tools, "angleLo": float(ang[0]), "angleHi": float(ang[1]),
		"alphaDeg": a0, "source": src }
	var names: Array = tools.map(func(id: String) -> String: return String({ "lima_fina": "lima fina", "lima_diamante_fina": "lima de diamante fina" }.get(id, id)))
	var with := " o ".join(PackedStringArray(names)) if not names.is_empty() else "una lima más dura que la punta (de diamante)"
	out["text"] = "Para afilar: %s, ángulo de %s-%s° (la garra es de %s°), poca presión, pasadas cortas en la punta, de la base a la punta." % [
		with, Js.to_fixed(float(ang[0]), 0), Js.to_fixed(float(ang[1]), 0), Js.to_fixed(a0, 0)]
	var tool_id := String(hand.get("tool", ""))
	var clipped := float(ts.flatMm) > 0.0
	out["show"] = zone == "roma" and (clipped or String(CareData.tool(tool_id).get("kind", "")) == "cortaunas")
	# (5v) con la garra rota (de serie o en la operación), lo que toca es repararla, no afilarla: la punta es la del muñón
	var dmg: Dictionary = care.broken_state()
	if bool(dmg.broken):
		out["show"] = false
	if not bool(out.show):
		return out
	if tool_id == "" or not is_filing(tool_id):
		out["fix"] = "Ahora: coge la %s." % String(names[0]) if not names.is_empty() else ""
	elif not tools.has(tool_id) and PURPOSES.has(tool_id) and String(PURPOSES[tool_id].sharpens) == "rapido":
		out["fix"] = "Ahora: %s afila en un instante y se pasa; con la lima, pasada a pasada, se para a tiempo." % _tool_name(tool_id)
	else:
		var angle := float(hand.get("angle_deg", 45.0))
		if angle >= ClawCare.TRUNCATE_DEG:
			out["fix"] = "Ahora: de frente (%s°) acorta; gira la lima a %s-%s° (A/D)." % [Js.to_fixed(angle, 0), Js.to_fixed(float(ang[0]), 0), Js.to_fixed(float(ang[1]), 0)]
		elif angle <= a0 + 1.0:
			out["fix"] = "Ahora: a %s° solo adelgaza los flancos; ábrela a %s-%s° (A/D)." % [Js.to_fixed(angle, 0), Js.to_fixed(float(ang[0]), 0), Js.to_fixed(float(ang[1]), 0)]
		elif angle > float(ang[1]) + 1e-9:
			out["fix"] = "Ahora: a %s° afila, pero deja la faceta más abierta que la garra («facetada»): mejor %s-%s°." % [Js.to_fixed(angle, 0), Js.to_fixed(float(ang[0]), 0), Js.to_fixed(float(ang[1]), 0)]
	return out


# ════════════════════════════════ La lupa de la punta ════════════════════════════════

## La punta a escala de micras: { apexMm, d (mm desde el vértice hacia la base), r (mm: el radio a esa distancia), tipRadiusUm,
## naturalUm, alphaDeg (el de la punta), naturalAlphaDeg, facetDeg, facetLenMm (el largo de la faceta, 0 sin faceta),
## facetFromR (el radio donde empieza, mm), flatMm,
## kind («natural» | «punta» | «cara»: la de la ficha, una punta del radio de los filos, una cara plana), startMm (donde
## empieza la punta dibujada: la esfera tangente al cono de la faceta queda algo por detrás de su vértice), chipped, chip
## ({ lostMm, sMm, seed } de la mella), natural ({ d, r }: la punta natural, para comparar), fieldMm (lo que abarca),
## scaleUm (la barra de escala, dibujo) }. snap: la instantánea (para la última rotura); sin ella, la pide al motor.
static func lupa(care: ClawCare, snap: Dictionary = {}, field_mm: float = -1.0) -> Dictionary:
	var ts := care.tip_state()
	var a := care.apex_mm()
	var r_um := float(ts.tipRadiusUm)
	var r0_um := float(ts.naturalUm)
	var R := r_um / 1000.0
	var r0 := r0_um / 1000.0
	var f := float(ts.flatMm)
	var face := f > 0.0 and f * 1000.0 >= r_um - 1e-9
	var natural := not face and absf(r_um - r0_um) < 1e-9 and float(ts.facetDeg) <= 0.0
	var kind := "cara" if face else ("natural" if natural else "punta")
	var field := field_mm if field_mm > 0.0 else clampf(6.0 * maxf(maxf(R, r0), f), 0.4, 4.0)
	field = minf(field, maxf(a, 0.05))
	# la pendiente de la garra junto al vértice (la del motor, para la esfera tangente de una punta del radio de los filos)
	var tip0 := ClawSharpness.tip_of(r0_um, float(ts.naturalAlphaDeg))
	var sharp := {}
	if kind == "punta":
		var dd := maxf(a - floorf(a / ClawCare.STATION_MM - 1e-9) * ClawCare.STATION_MM, 1e-4)
		if dd < 1e-3:
			dd = ClawCare.STATION_MM
		var slope := maxf((care.radius_at(a - dd) - care.radius_at(a)) / dd, 1e-3)
		var sn := slope / sqrt(1.0 + slope * slope)
		var cs := 1.0 / sqrt(1.0 + slope * slope)
		var dc := R / sn
		sharp = { "dc": dc, "da": dc - R, "dt": R * cs * cs / sn }
	var ds := PackedFloat64Array()
	var rs := PackedFloat64Array()
	var start := float(sharp.get("da", 0.0))
	# muestras: más juntas cerca del vértice (desde una fracción del radio de la punta) y hasta field
	var d0 := maxf(minf(R, r0) * 0.05, 1e-4)
	var n_geo := 40
	var d := start
	ds.append(d)
	rs.append(_lupa_r(care, a, d, kind, f, tip0, sharp))
	for i in n_geo:
		var u := float(i + 1) / float(n_geo)
		var dn := start + d0 * V8.js_pow(maxf(field - start, d0) / d0, u)
		if dn <= d + 1e-7:
			continue
		d = dn
		ds.append(d)
		rs.append(_lupa_r(care, a, d, kind, f, tip0, sharp))
	var nd := PackedFloat64Array()
	var nr := PackedFloat64Array()
	for i in 41:
		var dn2 := field * float(i) / 40.0
		nd.append(dn2)
		nr.append(Contact.contact_radius(tip0, dn2))
	var lb: Variant = snap.get("damage", {}).get("lastBreak") if not snap.is_empty() else care.snapshot().damage.get("lastBreak")
	var chipped := false
	var chip := {}
	if lb is Dictionary and String((lb as Dictionary).get("kind", "")) == "mella" and absf(float((lb as Dictionary).get("sMm", -1.0)) - a) < 1e-6 and f > 0.0:
		chipped = true
		chip = { "lostMm": float((lb as Dictionary).get("pieceMm", 0.0)), "sMm": a, "seed": "mella:%s:%s" % [Js.to_fixed(a, 4), Js.to_fixed(float((lb as Dictionary).get("tS", 0.0)), 3)] }
	var flen := facet_length_mm(care)
	return {
		"apexMm": a, "d": ds, "r": rs, "tipRadiusUm": r_um, "naturalUm": r0_um, "alphaDeg": float(ts.alphaDeg),
		"naturalAlphaDeg": float(ts.naturalAlphaDeg), "facetDeg": float(ts.facetDeg), "facetLenMm": flen,
		"facetFromR": care.radius_at(a - flen) if flen > 0.0 else 0.0,
		"flatMm": f, "kind": kind, "startMm": start, "chipped": chipped, "chip": chip, "natural": { "d": nd, "r": nr },
		"fieldMm": field, "scaleUm": scale_bar_um(field * 1000.0),
	}


## El radio (mm) de la punta dibujada a d mm del vértice: el del motor; en la natural, la esfera de su ficha (la del motor
## entre estaciones va en línea recta); en una punta del radio de los filos, la esfera tangente al cono del motor.
static func _lupa_r(care: ClawCare, a: float, d: float, kind: String, f: float, tip0: Dictionary, sharp: Dictionary) -> float:
	var r_eng := care.radius_at(a - d) if d > 0.0 else (f if kind == "cara" else 0.0)
	match kind:
		"natural":
			return maxf(r_eng, Contact.contact_radius(tip0, d))
		"punta":
			var dc := float(sharp.dc)
			var R := dc - float(sharp.da)
			if d < float(sharp.da):
				return 0.0
			if d <= float(sharp.dt):
				return sqrt(maxf(R * R - (d - dc) * (d - dc), 0.0))
			return r_eng
	return r_eng


## El largo de la faceta (mm): desde el vértice (o desde el borde de la cara plana) hacia la base mientras el perfil del motor
## baja con la pendiente de la faceta (tan facetDeg); 0 sin faceta.
static func facet_length_mm(care: ClawCare) -> float:
	var ts := care.tip_state()
	var fdeg := float(ts.facetDeg)
	if fdeg <= 0.0:
		return 0.0
	var t := V8.js_tan(fdeg * Contact.DEG)
	var tol := 0.02 + 0.08 * t
	var st := ClawCare.STATION_MM
	var a := care.apex_mm()
	var s_hi := a
	var r_hi := care.radius_at(a)
	var s := floorf(a / st - 1e-9) * st
	if a - s < 1e-6:
		s -= st
	var start := a
	while s >= 0.0:
		var r := care.radius_at(s)
		var slope := (r - r_hi) / maxf(s_hi - s, 1e-9)
		if absf(slope - t) > tol:
			break
		start = s
		s_hi = s
		r_hi = r
		s -= st
	return a - start


## La barra de escala (µm, dibujo): 1, 2 o 5 por una potencia de diez, hacia un tercio de lo que abarca la lupa.
static func scale_bar_um(field_um: float) -> float:
	var want := maxf(field_um / 3.0, 1.0)
	var p := 1.0
	while p * 10.0 <= want:
		p *= 10.0
	for k: float in [5.0, 2.0, 1.0]:
		if k * p <= want:
			return k * p
	return p


# ════════════════════════════════ Todo junto ════════════════════════════════

## El medidor, la lupa y el aviso de la garra que se trabaja (lo que pide la interfaz de una vez): { meter, lupa, advice, key }.
## key cambia si cambia lo que enseñan (la forma de la punta y la mano).
static func view(care: ClawCare, hand: Dictionary = {}, snap: Dictionary = {}) -> Dictionary:
	return { "meter": meter(care, hand), "lupa": lupa(care, snap), "advice": advice(care, hand), "key": key_of(care, hand) }


## La clave de lo que enseña la vista: la punta (largo, radio, cara, faceta) y la mano (herramienta, fuerza, ángulo, rpm).
static func key_of(care: ClawCare, hand: Dictionary) -> String:
	var ts := care.tip_state()
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [var_to_str(care.apex_mm()), var_to_str(float(ts.tipRadiusUm)), var_to_str(float(ts.flatMm)),
		var_to_str(float(ts.facetDeg)), String(hand.get("tool", "")), var_to_str(float(hand.get("force_n", 0.0))),
		var_to_str(float(hand.get("angle_deg", 0.0))), var_to_str(float(hand.get("rpm", 0.0))), str(care.kit().serial) + var_to_str(care.broken_state())]
