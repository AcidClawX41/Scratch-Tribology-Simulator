## Virutas del torno (unidad 9): qué forma tienen según el material, de qué color salen según la velocidad de
## corte y cómo vuelan hasta la bandeja.
##
## Determinista: todo el azar sale de core/shared/rng.gd con una semilla de texto; la misma secuencia de
## llamadas (emit/step con los mismos dt) da exactamente las mismas virutas en cualquier máquina. Sin nodos: la
## escena copia `buffer` en un MultiMesh (TRANSFORM_3D + colores) y usa `count` como instancias visibles.
##
## Coordenadas: metros, con +y hacia arriba (la gravedad va hacia −y); el marco es el de la escena del torno.
## Unidades de entrada: vc en m/min (CONTRATOS.md), tiempos en s.
##
## Uso:
##   const Chips = preload("res://core/taller/chips.gd")
##   var ch := Chips.new("acero", "torno:virutas", 400)
##   ch.emit(dt, punta, direccion, Chips.rate_for("acero", pc_kw, rpm), vc)
##   ch.step(dt)
##   multimesh.buffer = ch.buffer; multimesh.visible_instance_count = ch.count
##
## Física de la viruta (fase 2, funciones estáticas y puras; fuentes en docs/taller/pulido-taller.md):
##   chip_breaking(p)   rotura de la viruta en torneado de acero: Spanformdiagramm del Tabellenbuch (p. 204, C45 a
##                      200 m/min): zona de viruta favorable, criterio de superficie y viruta larga si no rompe.
##   bue_risk(p)        riesgo de filo recrecido: materiales pegajosos (acero, inoxidable, aluminio) a vc baja.
##   form_for_cut(...)  forma que se dibuja según el material y, en acero, según f y ap.
##   TZ_CHIP_FORMS      formas de viruta del TZ (p. 203) con su clase y su Spanraumzahl (volumen de viruta suelta).
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")
const Js = preload("res://core/shared/js.gd")
const WorkMaterials = preload("res://core/taller/work_materials.gd")
const ToolMaterials = preload("res://core/taller/tool_materials.gd")

const SRC_TZ_FORMS := (
	"Tabellenbuch Zerspantechnik (2015), p. 203: formas de viruta desfavorables, aceptables y favorables, y Spanraumzahl "
	+ "R = volumen de viruta / volumen arrancado (≥ 90 cinta y enredada … ≥ 3 fragmentos)"
)
const SRC_TZ_DIAGRAM := (
	"Tabellenbuch Zerspantechnik (2015), p. 204: Spanformdiagramm (ap frente a f) del C45 a vc = 200 m/min, zonas del "
	+ "criterio de rotura de la viruta y del criterio de superficie (digitalizado: ±0,05 mm en ap, ±0,01 mm en f)"
)
const SRC_BUE := (
	"Sandvik Coromant, «Wear on cutting edges»: el filo recrecido es la viruta soldada a presión a la plaquita, más "
	+ "común en materiales pegajosos (acero de bajo carbono, inoxidable y aluminio), y la vc baja lo favorece. TZ (2015), "
	+ "p. 213: adhesión → filo recrecido. Ahmed et al. (2017), Materials 10:1230, doi:10.3390/ma10111230: AISI 304 con "
	+ "metal duro sin recubrir, filo recrecido provocado a vc = 60 m/min (con más vc, menos)"
)

## Formas de viruta del TZ (p. 203): nombre alemán, clase y Spanraumzahl mínima R (null donde la tabla no la da).
const TZ_CHIP_FORMS := {
	"cinta": { "tz": "Bandspäne", "class": "desfavorable", "r_min": 90.0 },
	"enredada": { "tz": "Wirrspäne", "class": "desfavorable", "r_min": 90.0 },
	"helicoidal_plana": { "tz": "Flachwendelspäne", "class": "desfavorable", "r_min": 50.0 },
	"helicoidal_oblicua": { "tz": "Schrägwendelspäne", "class": "aceptable", "r_min": null },
	"helicoidal_larga": { "tz": "lange zylindrische Wendelspäne", "class": "aceptable", "r_min": 50.0 },
	"rizos": { "tz": "Spanlocken", "class": "aceptable", "r_min": 8.0 },
	"fragmentos": { "tz": "Bröckelspäne", "class": "aceptable", "r_min": 3.0 },
	"helicoidal_corta": { "tz": "kurze zylindrische Wendelspäne", "class": "favorable", "r_min": 25.0 },
	"espiral_helicoidal": { "tz": "Spiralwendelspäne", "class": "favorable", "r_min": null },
	"espiral": { "tz": "Spiralspäne", "class": "favorable", "r_min": 8.0 },
}
## Spanformdiagramm del TZ (p. 204), C45 a vc = 200 m/min, en [ap (mm), f (mm/rev)]. Zona de viruta favorable (criterio
## de rotura) y, dentro de ella, la que cumple también el criterio de superficie.
const TZ_DIAGRAM_VC := 200.0
const TZ_BREAK_ZONE_C45 := [[1.0, 0.200], [3.55, 0.154], [6.0, 0.241], [6.0, 0.656], [3.65, 0.709], [1.0, 0.709]]
const TZ_SURFACE_ZONE_C45 := [[1.0, 0.200], [2.09, 0.182], [3.98, 0.265], [4.01, 0.303], [1.0, 0.633]]
## Bordes inferior (debajo, la viruta es demasiado fina para romper) y superior (encima, el TZ no da datos) de la zona
const TZ_BREAK_LOWER_C45 := [[1.0, 0.200], [3.55, 0.154], [6.0, 0.241]]
const TZ_BREAK_UPPER_C45 := [[1.0, 0.709], [3.65, 0.709], [6.0, 0.656]]
## Materiales pegajosos, en los que se forma filo recrecido (Sandvik Coromant)
const BUE_KINDS := ["acero", "inox", "aluminio"]
## Grupo ISO 513 de cada tipo de material, cuando no se da el material
const KIND_ISO := { "acero": "P", "inox": "M", "fundicion": "K", "aluminio": "N", "laton": "N", "titanio": "S", "niquel": "S" }

const FLOATS := 16  ## floats por instancia en MultiMesh.buffer: transformación (3 filas × 4) + color RGBA
const FORMS := ["rizada", "espiral", "astillada"]
const FLYING := 1
const RESTING := 2

## Forma de viruta por `kind` del material de pieza (CONTRATOS.md → Material de pieza).
## Formas de ISO 3685:1993, anexo G: rizada = viruta en arco (clase 6, la que deja un rompevirutas),
## espiral = tubular o helicoidal (clases 2, 4 y 5), astillada = elemental o de aguja (clases 7 y 8).
## - base: color del metal (F0 en sRGB lineal, Hoffman 2015) o albedo del no metal.
## - temper_shift: °C que se suman a la escala de colores de revenido del acero al carbono; null si ese material
##   no toma colores de óxido visibles en la viruta.
## - zeta: razón de compresión de la viruta (espesor de viruta / espesor sin deformar); la viruta sale a vc/ζ.
## - size: tamaño típico (m) de la pieza de viruta que se dibuja.
const KINDS := {
	"acero": {"form": "rizada", "base": Color(0.562, 0.565, 0.578), "metal": true, "temper_shift": 0.0, "zeta": 2.2, "size": 1.0,
		"source": "ISO 3685:1993 anexo G; Sandvik Coromant, Training Handbook (ISO P: viruta larga, controlable con rompevirutas)", "quality": "secondary"},
	"inox": {"form": "espiral", "base": Color(0.60, 0.59, 0.57), "metal": true, "temper_shift": 100.0, "zeta": 2.6, "size": 1.0,
		"source": "Sandvik Coromant, Training Handbook (ISO M: viruta larga y tenaz); desplazamiento de la escala de colores: estimación", "quality": "estimate"},
	"fundicion": {"form": "astillada", "base": Color(0.20, 0.20, 0.21), "metal": false, "temper_shift": null, "zeta": 1.3, "size": 0.8,
		"source": "Sandvik Coromant, Training Handbook (ISO K: viruta corta, fragmentada)", "quality": "secondary"},
	"aluminio": {"form": "espiral", "base": Color(0.913, 0.922, 0.924), "metal": true, "temper_shift": null, "zeta": 1.8, "size": 1.1,
		"source": "Sandvik Coromant, Training Handbook (ISO N: viruta larga en las aleaciones de forja)", "quality": "secondary"},
	"laton": {"form": "astillada", "base": Color(0.887, 0.789, 0.434), "metal": true, "temper_shift": null, "zeta": 1.4, "size": 1.0,
		"source": "Latón de corte libre (CuZn39Pb3): viruta corta y quebradiza por el plomo (guías de mecanizado de la Copper Development Association); F0 del latón: estimación entre cobre y cinc", "quality": "secondary"},
	"titanio": {"form": "rizada", "base": Color(0.542, 0.497, 0.449), "metal": true, "temper_shift": 150.0, "zeta": 1.2, "size": 0.9,
		"source": "Viruta segmentada (en diente de sierra) del Ti-6Al-4V (Komanduri y von Turkovich, Wear 69, 1981); desplazamiento de colores: estimación", "quality": "estimate"},
	"niquel": {"form": "espiral", "base": Color(0.660, 0.609, 0.526), "metal": true, "temper_shift": 120.0, "zeta": 2.4, "size": 1.0,
		"source": "Sandvik Coromant, Training Handbook (ISO S, superaleaciones: viruta tenaz); colores: estimación", "quality": "estimate"},
	"madera": {"form": "rizada", "base": Color(0.55, 0.36, 0.18), "metal": false, "temper_shift": null, "zeta": 1.5, "size": 1.3,
		"source": "estimación (virutas rizadas del torneado de madera)", "quality": "estimate"},
	"plastico": {"form": "espiral", "base": Color(0.80, 0.80, 0.78), "metal": false, "temper_shift": null, "zeta": 1.3, "size": 1.1,
		"source": "estimación (viruta continua de los termoplásticos)", "quality": "estimate"},
	"piedra": {"form": "astillada", "base": Color(0.35, 0.33, 0.30), "metal": false, "temper_shift": null, "zeta": 1.0, "size": 0.6,
		"source": "estimación (fragmentos y polvo)", "quality": "estimate"},
	"vidrio": {"form": "astillada", "base": Color(0.70, 0.75, 0.75), "metal": false, "temper_shift": null, "zeta": 1.0, "size": 0.6,
		"source": "estimación (esquirlas)", "quality": "estimate"},
}

## Colores de revenido del acero al carbono: temperatura (°C) a la que aparece cada color de la capa de óxido.
## Temperaturas: tabla clásica de colores de revenido (Machinery's Handbook; Wikipedia, «Tempering
## (metallurgy)»). Los RGB (sRGB) son una aproximación visual: estimación.
const TEMPER := [
	[200.0, "#DCCDA4"], [220.0, "#D8B96C"], [240.0, "#C9964A"], [255.0, "#A96F3B"], [265.0, "#8D4F4B"],
	[275.0, "#8A4A86"], [285.0, "#5E4AA8"], [295.0, "#3553B0"], [310.0, "#5B8FD6"], [330.0, "#86A0B8"], [360.0, "#8D9195"],
]
## Temperatura de la viruta (°C) según vc: estimación calibrada con la regla de taller «con metal duro a la vc
## recomendada para el acero (≈ 200 m/min) la viruta sale azul (≈ 300 °C); con acero rápido (≈ 30 m/min), sin
## color». T = 20 + 280·√(vc/200).
const T_REF := 280.0
const VC_REF := 200.0

var kind := "acero"
var form := "rizada"
var capacity := 400
var count := 0  ## instancias en uso (visible_instance_count del MultiMesh)
var emitted := 0  ## virutas emitidas desde el principio
var buffer := PackedFloat32Array()  ## MultiMesh.buffer (TRANSFORM_3D + colores)
var floor_y := 0.0  ## altura de la bandeja de virutas (m)
var gravity := 9.81  ## m/s²
var drag := 1.8  ## 1/s: frenado del aire de una viruta ligera (estimación visual)
var max_step := 1.0 / 60.0  ## subpaso máximo de la integración (s)

var _rng: Rng
var _acc := 0.0
var _next := 0
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _axis := PackedVector3Array()
var _ang := PackedFloat64Array()
var _spin := PackedFloat64Array()
var _scale := PackedFloat64Array()
var _age := PackedFloat64Array()
var _state := PackedByteArray()
var _color := PackedColorArray()
var _rest_on := PackedInt32Array()  # superficie en la que reposa cada viruta (−1: la bandeja)
var _boxes: Array[Dictionary] = []  # superficies de reposo: {"rect": Rect2 en (x, z), "y": float}


func _init(p_kind := "acero", seed_text := "torno:virutas", p_capacity := 400) -> void:
	capacity = maxi(1, p_capacity)
	_rng = Rng.new(Rng.seed_of(seed_text))
	for arr: Variant in [_pos, _vel, _axis, _ang, _spin, _scale, _age, _state, _color, _rest_on]:
		arr.resize(capacity)
	_rest_on.fill(-1)
	buffer.resize(capacity * FLOATS)
	set_kind(p_kind)


## Cambia el material de las próximas virutas (las que ya están en el aire o en la bandeja no cambian).
func set_kind(p_kind: String) -> void:
	kind = p_kind if KINDS.has(p_kind) else "acero"
	form = KINDS[kind]["form"]


## Superficie horizontal donde pueden quedarse las virutas: la cara de arriba de una pieza de la máquina, con
## `rect` en el plano (x, z) y altura y (m). Si la superficie ya existía y se ha movido (el carro), las virutas
## que reposan en ella se mueven con ella. La bandeja (floor_y) recoge todo lo demás.
func set_box(id: int, rect: Rect2, y: float) -> void:
	while _boxes.size() <= id:
		_boxes.append({})
	var old: Dictionary = _boxes[id]
	_boxes[id] = {"rect": rect, "y": y}
	if old.is_empty():
		return
	var prev: Rect2 = old["rect"]
	var d := Vector3(rect.position.x - prev.position.x, y - float(old["y"]), rect.position.y - prev.position.y)
	if d == Vector3.ZERO:
		return
	for i in count:
		if _state[i] == RESTING and _rest_on[i] == id:
			_pos[i] += d
			_write(i)


## Altura del apoyo bajo (x, z) para una viruta que venía de y_prev: la superficie más alta que tenga debajo, o la
## bandeja. Devuelve Vector2(altura, id de la superficie o −1).
func ground_at(x: float, z: float, y_prev: float) -> Vector2:
	var g := Vector2(floor_y, -1.0)
	for b in _boxes.size():
		var box: Dictionary = _boxes[b]
		if box.is_empty():
			continue
		var y := float(box["y"])
		if y > g.x and y <= y_prev + 1e-6 and (box["rect"] as Rect2).has_point(Vector2(x, z)):
			g = Vector2(y, float(b))
	return g


## Forma de viruta de un material («rizada», «espiral» o «astillada»).
static func form_for(p_kind: String) -> String:
	return KINDS.get(p_kind, KINDS["acero"])["form"]


## Temperatura estimada de la viruta (°C) a una velocidad de corte vc (m/min).
static func chip_temperature(vc: float) -> float:
	return 20.0 + T_REF * sqrt(maxf(vc, 0.0) / VC_REF)


## Color de la viruta (sRGB lineal) de un material cortado a vc (m/min): el metal limpio por debajo de 200 °C y,
## por encima, el color de revenido interpolado. Los materiales sin colores de óxido devuelven su color base.
static func temper_color(p_kind: String, vc: float) -> Color:
	var k: Dictionary = KINDS.get(p_kind, KINDS["acero"])
	var base: Color = k["base"]
	if k["temper_shift"] == null:
		return base
	var t := chip_temperature(vc) - float(k["temper_shift"])
	var first: Array = TEMPER[0]
	if t <= float(first[0]) - 20.0:
		return base
	if t <= float(first[0]):  # de metal limpio al primer amarillo pálido en 20 °C
		return base.lerp(Color(first[1]).srgb_to_linear(), (t - (float(first[0]) - 20.0)) / 20.0)
	for i in range(1, TEMPER.size()):
		var hi: Array = TEMPER[i]
		if t <= float(hi[0]):
			var lo: Array = TEMPER[i - 1]
			var f := (t - float(lo[0])) / (float(hi[0]) - float(lo[0]))
			return Color(lo[1]).srgb_to_linear().lerp(Color(hi[1]).srgb_to_linear(), f)
	return Color(TEMPER[TEMPER.size() - 1][1]).srgb_to_linear()


## Virutas por segundo que se dibujan (no las reales: una viruta dibujada representa un trozo). Estimación
## visual: la rizada rompe cada pocas vueltas, la espiral es larga y sale poca, la astillada sale a puñados; la
## potencia de corte (kW) escala el caudal.
static func rate_for(p_kind: String, pc_kw: float, rpm: float) -> float:
	if pc_kw <= 0.0 or rpm == 0.0:  # rpm negativas: cabezal al revés (M04), también corta
		return 0.0
	var rev_s := absf(rpm) / 60.0
	var p := clampf(pc_kw / 2.0, 0.25, 1.6)
	match form_for(p_kind):
		"espiral":
			return clampf(rev_s * 0.12, 0.8, 5.0) * p
		"astillada":
			return clampf(rev_s * 2.5, 8.0, 90.0) * p
		_:
			return clampf(rev_s * 1.5, 4.0, 60.0) * p


# ─────────────────────────────── Física de la viruta (fase 2) ───────────────────────────────

## Rotura de la viruta en torneado según el Spanformdiagramm del TZ (p. 204: C45 a vc = 200 m/min).
## p = { work_id (opcional: su `kind` manda) o kind, f_mm (avance, mm/rev), ap_mm, vc (m/min) } →
## { zone: "favorable" | "viruta_larga" | "fuera_del_diagrama" | "sin_datos", surface_ok: bool | null, form (la que se
##   dibuja: FORMS), tz_form (clave de TZ_CHIP_FORMS) | null, tz_class, chip_ratio_min (Spanraumzahl R mínima) | null,
##   quality, source, message }.
## - Solo el acero tiene diagrama: C45 cerca de 200 m/min es «secondary» (figura digitalizada); otro acero u otra vc,
##   la misma figura como estimación. El resto: «sin_datos» y la forma típica de su grupo (KINDS).
## - Por debajo del borde inferior o con ap < 1 mm la viruta es demasiado fina o estrecha para romper: viruta larga
##   (cinta o enredada, R ≥ 90). Por encima del borde superior o con ap > 6 mm el TZ no da datos.
static func chip_breaking(p: Dictionary) -> Dictionary:
	var work := WorkMaterials.get_material(str(p.get("work_id", "")))
	var kind := str(work["kind"]) if not work.is_empty() else str(p.get("kind", "acero"))
	var f := float(p.get("f_mm", 0.0))
	var ap := float(p.get("ap_mm", 0.0))
	var vc := float(p.get("vc", TZ_DIAGRAM_VC))
	var out := {
		"zone": "sin_datos", "surface_ok": null, "form": form_for(kind), "tz_form": null, "tz_class": "",
		"chip_ratio_min": null, "quality": "estimate", "source": SRC_TZ_DIAGRAM, "message": "",
	}
	if kind != "acero":
		out["message"] = "El TZ solo da el diagrama de rotura de la viruta del acero C45: en %s se dibuja la forma típica de su grupo." % [
			_kind_label(kind)]
		out["source"] = str(KINDS.get(kind, KINDS["acero"])["source"])
		return out
	if f <= 0.0 or ap <= 0.0:
		out["message"] = "Sin avance o sin profundidad no hay viruta."
		return out
	var is_c45 := not work.is_empty() and str(work["id"]) == "c45e"
	out["quality"] = "secondary" if is_c45 and absf(vc - TZ_DIAGRAM_VC) <= 50.0 else "estimate"
	if _in_polygon(ap, f, TZ_BREAK_ZONE_C45):
		var surface := _in_polygon(ap, f, TZ_SURFACE_ZONE_C45)
		out["zone"] = "favorable"
		out["surface_ok"] = surface
		out["form"] = "rizada"
		out["tz_form"] = "helicoidal_corta"
		out["tz_class"] = "favorable"
		out["chip_ratio_min"] = TZ_CHIP_FORMS["helicoidal_corta"]["r_min"]
		out["source"] = SRC_TZ_DIAGRAM + "; " + SRC_TZ_FORMS
		out["message"] = "Viruta favorable: rompe en trozos cortos (f = %s mm, ap = %s mm)." % [Js.to_fixed(f, 2), Js.to_fixed(ap, 1)]
		if not surface:
			out["message"] += " Pero queda fuera de la zona del criterio de superficie del TZ: para un buen acabado, menos avance o menos profundidad."
		return out
	if ap <= 6.0 and f <= _upper_break_f(ap) and (ap < 1.0 or f < _lower_break_f(ap)):
		out["zone"] = "viruta_larga"
		out["surface_ok"] = false
		out["form"] = "espiral"
		out["tz_form"] = "enredada"
		out["tz_class"] = "desfavorable"
		out["chip_ratio_min"] = TZ_CHIP_FORMS["enredada"]["r_min"]
		out["source"] = SRC_TZ_DIAGRAM + "; " + SRC_TZ_FORMS
		out["message"] = "Viruta larga y enredada (desfavorable según el TZ): con f = %s mm y ap = %s mm es demasiado fina o estrecha para romper. Más avance o más profundidad, o un rompevirutas para ese avance." % [
			Js.to_fixed(f, 2), Js.to_fixed(ap, 1)]
		return out
	out["zone"] = "fuera_del_diagrama"
	out["message"] = "f = %s mm y ap = %s mm quedan por encima del diagrama de formas de viruta del TZ (ap de 1 a 6 mm, f hasta ~0,7 mm): sin datos de rotura." % [
		Js.to_fixed(f, 2), Js.to_fixed(ap, 1)]
	return out


## Forma que se dibuja para un corte: en acero, la que da el diagrama del TZ (favorable → rizada, larga → espiral); en
## el resto, la típica de su grupo (form_for).
static func form_for_cut(p_kind: String, f_mm: float, ap_mm: float, vc: float) -> String:
	if p_kind != "acero":
		return form_for(p_kind)
	return str(chip_breaking({ "kind": p_kind, "f_mm": f_mm, "ap_mm": ap_mm, "vc": vc })["form"])


## Riesgo de filo recrecido: la viruta se suelda al filo en los materiales pegajosos (acero, inoxidable, aluminio) y lo
## favorece la vc baja (Sandvik Coromant). Umbral (estimación): el mínimo del intervalo de vc recomendado de la
## herramienta en el grupo ISO del material (TZ p. 208 en acero); Ahmed et al. (2017) lo provocan en AISI 304 con metal
## duro sin recubrir a 60 m/min, justo ese mínimo.
## p = { work_id (o kind), tool_id, vc (m/min) } → { risk: bool, vc_limit (m/min) | null, message, quality, source }.
static func bue_risk(p: Dictionary) -> Dictionary:
	var work := WorkMaterials.get_material(str(p.get("work_id", "")))
	var kind := str(work["kind"]) if not work.is_empty() else str(p.get("kind", ""))
	var iso := str(work["iso"]) if not work.is_empty() else str(KIND_ISO.get(kind, ""))
	var tool := ToolMaterials.get_tool(str(p.get("tool_id", "")))
	var vc := float(p.get("vc", 0.0))
	var out := { "risk": false, "vc_limit": null, "message": "", "quality": "estimate", "source": SRC_BUE }
	if not BUE_KINDS.has(kind):
		if kind != "":
			var label := _kind_label(kind)
			out["message"] = "%s no es un material pegajoso: sin filo recrecido apreciable." % (label[0].to_upper() + label.substr(1))
		return out
	if tool.is_empty() or not (tool["vc_range"] as Dictionary).has(iso):
		out["message"] = "Sin intervalo de vc de esa herramienta para el grupo ISO %s: no se evalúa el filo recrecido." % iso
		return out
	var lo := float(tool["vc_range"][iso][0])
	out["vc_limit"] = lo
	if vc > 0.0 and vc <= lo:
		out["risk"] = true
		out["message"] = "Riesgo de filo recrecido: a %s m/min, en el mínimo del intervalo de %s en el grupo %s (%s m/min) o por debajo, la viruta de %s se suelda a presión al filo, crece y se desprende: el acabado sale irregular. Sube la velocidad de corte." % [
			Js.to_fixed(vc, 0), str(tool["name"]), iso, Js.to_fixed(lo, 0), _kind_label(kind)]
	return out


## Punto (x, y) dentro de un polígono [[x, y], …] (rayos; el borde cuenta como dentro). En float64, no en Vector2
## (float32), para que un punto del borde dé lo mismo en todas las plataformas.
static func _in_polygon(x: float, y: float, poly: Array) -> bool:
	var n := poly.size()
	var inside := false
	var j := n - 1
	for i in n:
		var ax := float(poly[i][0])
		var ay := float(poly[i][1])
		var bx := float(poly[j][0])
		var by := float(poly[j][1])
		if _on_segment(x, y, ax, ay, bx, by):
			return true
		if (ay > y) != (by > y):
			var xc := ax + (y - ay) / (by - ay) * (bx - ax)
			if x < xc:
				inside = not inside
		j = i
	return inside


static func _on_segment(x: float, y: float, ax: float, ay: float, bx: float, by: float) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var px := x - ax
	var py := y - ay
	var len2 := dx * dx + dy * dy
	if absf(dx * py - dy * px) > 1e-9 * maxf(sqrt(len2), 1.0):
		return false
	var t := (px * dx + py * dy) / maxf(len2, 1e-300)
	return t >= -1e-12 and t <= 1.0 + 1e-12


## Avance mínimo (mm) para que la viruta rompa a esa profundidad: el borde inferior de la zona del TZ.
static func _lower_break_f(ap: float) -> float:
	return _polyline_y(TZ_BREAK_LOWER_C45, ap)


## Avance máximo (mm) del diagrama a esa profundidad: el borde superior de la zona del TZ (por encima, sin datos).
static func _upper_break_f(ap: float) -> float:
	return _polyline_y(TZ_BREAK_UPPER_C45, ap)


## y de una poligonal [[x, y], …] ordenada en x, con los extremos prolongados en horizontal.
static func _polyline_y(pts: Array, x: float) -> float:
	if x <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		if x <= float(pts[i][0]):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			return float(a[1]) + (x - float(a[0])) / (float(b[0]) - float(a[0])) * (float(b[1]) - float(a[1]))
	return float(pts[pts.size() - 1][1])


## Nombre del tipo de material para los textos.
static func _kind_label(kind: String) -> String:
	var names := { "acero": "acero", "inox": "acero inoxidable", "fundicion": "fundición", "aluminio": "aluminio",
		"laton": "latón", "titanio": "titanio", "niquel": "aleación de níquel", "madera": "madera", "plastico": "plástico",
		"piedra": "piedra", "vidrio": "vidrio" }
	return str(names.get(kind, kind))


## Emite las virutas que tocan en `dt` desde la punta de la herramienta.
## - tip: punto de salida (m); flow: dirección media de salida (no hace falta normalizarla);
## - rate: virutas por segundo (rate_for); vc: velocidad de corte (m/min), para la velocidad y el color.
## Devuelve cuántas ha emitido.
func emit(dt: float, tip: Vector3, flow: Vector3, rate: float, vc: float) -> int:
	if rate <= 0.0 or dt <= 0.0:
		return 0
	_acc += rate * dt
	var n := 0
	var k: Dictionary = KINDS[kind]
	var dir0 := flow.normalized() if flow.length_squared() > 0.0 else Vector3.UP
	var speed0 := maxf(vc, 1.0) / 60.0 / float(k["zeta"])
	var color0 := temper_color(kind, vc)
	var spread := 0.55 if form == "astillada" else 0.3
	while _acc >= 1.0:
		_acc -= 1.0
		var i := _next
		_next = (_next + 1) % capacity
		var jitter := _unit() * 0.001
		_pos[i] = tip + jitter
		var d := (dir0 + _unit() * spread).normalized()
		var sp := speed0 * (0.7 + 0.6 * _rng.next())
		if form == "espiral":
			sp *= 0.45  # la espiral es larga y pesada: sale despacio y cae enseguida
		_vel[i] = d * sp
		_axis[i] = _unit()
		_ang[i] = TAU * _rng.next()
		_spin[i] = (6.0 if form == "espiral" else 18.0) * (0.5 + _rng.next()) * (1.0 if _rng.next() < 0.5 else -1.0)
		_scale[i] = float(k["size"]) * (0.7 + 0.6 * _rng.next())
		_age[i] = 0.0
		_state[i] = FLYING
		_rest_on[i] = -1
		var shade := 0.88 + 0.24 * _rng.next()
		_color[i] = Color(color0.r * shade, color0.g * shade, color0.b * shade, 1.0)
		_write(i)
		n += 1
	emitted += n
	count = mini(emitted, capacity)
	return n


## Avanza la balística: gravedad, frenado del aire, giro y reposo al llegar a la bandeja.
func step(dt: float) -> void:
	if dt <= 0.0:
		return
	var steps := maxi(1, int(ceil(dt / max_step)))
	var h := dt / float(steps)
	var damp := maxf(0.0, 1.0 - drag * h)
	for i in count:
		if _state[i] != FLYING:
			continue
		var p := _pos[i]
		var v := _vel[i]
		var a := _ang[i]
		var landed := false
		for s in steps:
			var y_prev := p.y
			v.y -= gravity * h
			v *= damp
			p += v * h
			a += _spin[i] * h
			var g := ground_at(p.x, p.z, y_prev) if not _boxes.is_empty() else Vector2(floor_y, -1.0)
			if p.y <= g.x:
				p.y = g.x + 0.0012 * _scale[i]  # apoyada: el centro de la viruta queda un poco por encima
				_rest_on[i] = int(g.y)
				landed = true
				break
		_pos[i] = p
		_vel[i] = v
		_ang[i] = a
		_age[i] += dt
		if landed or _age[i] > 6.0:
			_state[i] = RESTING
			_vel[i] = Vector3.ZERO
		_write(i)


## Virutas en el aire ahora mismo.
func flying() -> int:
	var n := 0
	for i in count:
		if _state[i] == FLYING:
			n += 1
	return n


## Posición de una viruta (m), para los tests y para depurar.
func position_of(i: int) -> Vector3:
	return _pos[i]


## Estado de una viruta: 0 libre, 1 en el aire, 2 en reposo.
func state_of(i: int) -> int:
	return _state[i]


func _write(i: int) -> void:
	var s := _scale[i]
	var b := Basis(_axis[i], _ang[i]).scaled(Vector3(s, s, s))
	var p := _pos[i]
	var c := _color[i]
	var o := i * FLOATS
	buffer[o] = b.x.x
	buffer[o + 1] = b.y.x
	buffer[o + 2] = b.z.x
	buffer[o + 3] = p.x
	buffer[o + 4] = b.x.y
	buffer[o + 5] = b.y.y
	buffer[o + 6] = b.z.y
	buffer[o + 7] = p.y
	buffer[o + 8] = b.x.z
	buffer[o + 9] = b.y.z
	buffer[o + 10] = b.z.z
	buffer[o + 11] = p.z
	buffer[o + 12] = c.r
	buffer[o + 13] = c.g
	buffer[o + 14] = c.b
	buffer[o + 15] = c.a


## Vector unitario uniforme sobre la esfera (dos números del generador).
func _unit() -> Vector3:
	var z := 2.0 * _rng.next() - 1.0
	var phi := TAU * _rng.next()
	var q := sqrt(maxf(0.0, 1.0 - z * z))
	return Vector3(q * cos(phi), q * sin(phi), z)
