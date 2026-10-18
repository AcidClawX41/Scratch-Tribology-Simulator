## Tribología biológica · cetrería: las herramientas del ensayo y lo que se gastan (unidad 5l, petición 38). Sin nodos y
## determinista. Lo comparten todas las garras de un animal (ClawCareState, como el animal: claw_care_patient.gd); una
## ClawCare sola tiene la suya.
##
## Cada herramienta de limar se gasta al trabajar (ClawCare.file → add): el volumen que pierde (Archard con la razón de
## durezas al revés, ClawCare.tool_wear_k) se reparte por las aristas o los granos de la tira de su cara que pasa por el
## contacto (el ancho del contacto por face_mm) y redondea cada filo (CareData.TOOL_WEAR):
##   - un diente de semiángulo θ que retrocede δ pierde δ²·tan θ por mm de arista;
##   - un grano (los que tocan, GRAIN_GEOMETRY.engaged), (π/3)·tan²θ·δ³;
##   - queda una plataforma de semiancho δ·tan θ que corta como una punta redonda de radio δ·tan θ/cos θ, combinada con el
##     radio de nueva: R = √(R0² + (δ·tan θ/cos θ)²).
## Ese radio es el que usa el arranque (worn_tool → tip_um en ClawCare.element_cut): una herramienta gastada nunca quita más
## que una nueva. Una nueva de la bandeja (renew) vuelve a cortar como el primer día.
## Unidades: mm, µm (radios y retrocesos), mm³.
## Uso: var kit := ClawCareKit.new(); ClawCare.new(setup, patient, kit); kit.view().
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")

## id → { area (mm² por mm de arista, dientes) | vol (mm³ por grano, granos), worn_mm3, slid_mm, rub_mm, passes, renewed }
var _wear: Dictionary = {}
## Número que cambia con cada cambio (la escena repinta las herramientas solo si cambia).
var serial := 0


func reset() -> void:
	_wear = {}
	serial += 1


## ¿Es una herramienta que se gasta (de limar: con dientes o grano)?
static func wears(tool_d: Dictionary) -> bool:
	return String(tool_d.get("kind", "")) in ["lima", "torno"] and float(tool_d.get("face_mm", 0.0)) > 0.0


## La geometría del filo de una herramienta: { tooth, theta (rad), r0_um }.
static func _edge(tool_d: Dictionary) -> Dictionary:
	var tooth := String(tool_d.get("element", "grano")) == "diente"
	var g: Dictionary = CareData.TOOTH_GEOMETRY if tooth else CareData.GRAIN_GEOMETRY
	return { "tooth": tooth, "theta": float(g.half_angle_deg) * Contact.DEG, "r0_um": float(g.tip_um) }


## Retroceso del filo (µm) con lo gastado: de un diente, √(A/tan θ) con A en mm² por mm de arista; de un grano,
## ∛(3V/(π·tan²θ)) con V en mm³ por grano.
static func recession_um(tool_d: Dictionary, e: Dictionary) -> float:
	var ed := _edge(tool_d)
	var t := V8.js_tan(float(ed.theta))
	if bool(ed.tooth):
		var a := float(e.get("area", 0.0))
		return sqrt(maxf(a, 0.0) / t) * 1000.0 if a > 0.0 else 0.0
	var v := float(e.get("vol", 0.0))
	return Js.cbrt(3.0 * maxf(v, 0.0) / (PI * t * t)) * 1000.0 if v > 0.0 else 0.0


## Radio (µm) que corta el filo con la plataforma de semiancho b = δ·tan θ: √(R0² + (b/cos θ)²). La plataforma no pasa del
## medio ancho del propio filo (flat_cap_um): un grano aplanado de lado a lado, o un diente romo hasta su base, ya no se
## gasta más (geometría).
static func edge_radius_um(tool_d: Dictionary, delta_um: float) -> float:
	var ed := _edge(tool_d)
	var r0 := float(ed.r0_um)
	if not (delta_um > 0.0):
		return r0
	var th := float(ed.theta)
	var b := minf(delta_um * V8.js_tan(th), flat_cap_um(tool_d))
	var r := b / V8.js_cos(th)
	return sqrt(r0 * r0 + r * r)


## El medio ancho más grande que puede tener la plataforma de un filo (µm): el del grano (su tamaño medio entre dos) o el del
## diente (medio paso del picado, 10/teeth_cm mm).
static func flat_cap_um(tool_d: Dictionary) -> float:
	if String(tool_d.get("element", "grano")) == "diente":
		return 0.5 * 10.0 / maxf(float(tool_d.get("teeth_cm", 10.0)), 1.0) * 1000.0
	return 0.5 * float(tool_d.get("grain_um", 100.0))


## El radio de los filos de esta herramienta ahora (µm): el de nueva si no se ha gastado.
func edge_um(tool_d: Dictionary) -> float:
	var e: Dictionary = _wear.get(String(tool_d.get("id", "")), {})
	return edge_radius_um(tool_d, recession_um(tool_d, e))


## La herramienta como está (una copia): con tip_um, el radio de sus filos gastados, si se ha gastado.
func worn_tool(tool_d: Dictionary) -> Dictionary:
	var out := tool_d.duplicate()
	if wears(tool_d) and _wear.has(String(tool_d.get("id", ""))):
		out["tip_um"] = edge_um(tool_d)
	return out


## Lo que se gasta en una pasada: dv_mm3 (el volumen que pierde la herramienta), repartido por la tira de ancho strip_mm de
## su cara; slid_mm, lo que ha deslizado; rub_mm, lo que ha deslizado sin morder.
func add(tool_d: Dictionary, dv_mm3: float, strip_mm: float, slid_mm: float, rub_mm: float = 0.0) -> void:
	if not wears(tool_d):
		return
	var id := String(tool_d.id)
	var e: Dictionary = _wear.get(id, { "area": 0.0, "vol": 0.0, "worn_mm3": 0.0, "slid_mm": 0.0, "rub_mm": 0.0, "passes": 0, "renewed": 0 })
	e["slid_mm"] = float(e.slid_mm) + maxf(slid_mm, 0.0)
	e["rub_mm"] = float(e.rub_mm) + maxf(rub_mm, 0.0)
	e["passes"] = int(e.passes) + 1
	if dv_mm3 > 0.0 and strip_mm > 0.0:
		e["worn_mm3"] = float(e.worn_mm3) + dv_mm3
		var w := minf(strip_mm, float(tool_d.get("band_mm", INF)))
		e["strip_mm"] = w
		var face := float(tool_d.face_mm)
		if bool(_edge(tool_d).tooth):
			# las filas de dientes de la tira: teeth_cm por cm a lo largo, cada una con w mm de arista
			var edges_mm := float(tool_d.teeth_cm) * face / 10.0 * w
			e["area"] = float(e.area) + dv_mm3 / edges_mm
		else:
			var d := float(tool_d.grain_um) / 1000.0
			var grains := maxf(float(CareData.GRAIN_GEOMETRY.engaged) * w * face / (d * d), 1.0)
			e["vol"] = float(e.vol) + dv_mm3 / grains
	_wear[id] = e
	serial += 1


## Una nueva de la bandeja: la herramienta id vuelve a estar como el primer día (se apunta cuántas se han cambiado).
func renew(id: String) -> void:
	var e: Dictionary = _wear.get(id, {})
	var n := int(e.get("renewed", 0)) + 1
	_wear[id] = { "area": 0.0, "vol": 0.0, "worn_mm3": 0.0, "slid_mm": 0.0, "rub_mm": 0.0, "passes": 0, "renewed": n }
	serial += 1


## Apunta que ya se ha avisado de que la herramienta id está gastada: true la primera vez (hasta que se cambie por una nueva).
func flag_dull(id: String) -> bool:
	var e: Dictionary = _wear.get(id, {})
	if e.is_empty() or bool(e.get("warned", false)):
		return false
	e["warned"] = true
	return true


## Cómo va una herramienta: { id, wears, deltaUm (lo que han retrocedido sus filos), flatUm (el ancho de la plataforma),
## stripMm (el ancho de la tira de su cara que ha trabajado),
## edgeUm (el radio que corta), edgeNewUm, dull (0-1: de nueva a con el doble de radio, CareData.TOOL_WEAR.dull_ratio),
## state («nueva» | «usada» | «gastada»), look («dientes» | «grano»: cómo se ve gastada: la lima embotada, el grano vidriado),
## word (la palabra: «embotada» o «vidriada»), wornMm3, slidMm, rubMm, passes, renewed, text, source }.
func state(tool_d: Dictionary) -> Dictionary:
	var id := String(tool_d.get("id", ""))
	var e: Dictionary = _wear.get(id, {})
	var ed := _edge(tool_d)
	var tooth := bool(ed.tooth)
	var r0 := float(ed.r0_um)
	var delta := recession_um(tool_d, e) if wears(tool_d) else 0.0
	var r := edge_radius_um(tool_d, delta)
	var ratio := float(CareData.TOOL_WEAR.dull_ratio.value)
	var dull := clampf((r - r0) / (r0 * (ratio - 1.0)), 0.0, 1.0)
	var st := "nueva"
	if dull >= 1.0:
		st = "gastada"
	elif dull >= 0.05:
		st = "usada"
	var word := "embotada" if tooth else "vidriada"
	var text := ""
	match st:
		"nueva":
			text = "Como nueva: filos de %s µm." % Js.to_fixed(r, 1)
		"usada":
			text = "Usada: los filos han pasado de %s a %s µm de radio." % [Js.to_fixed(r0, 0), Js.to_fixed(r, 1)]
		"gastada":
			text = "%s: los filos han pasado de %s a %s µm de radio; corta mucho menos. Coge una nueva de la bandeja." % [word.capitalize(), Js.to_fixed(r0, 0), Js.to_fixed(r, 1)]
	return {
		"id": id, "wears": wears(tool_d), "deltaUm": delta, "flatUm": 2.0 * minf(delta * V8.js_tan(float(ed.theta)), flat_cap_um(tool_d)), "edgeUm": r,
		"edgeNewUm": r0, "dull": dull, "state": st, "look": "dientes" if tooth else "grano", "word": word,
		"wornMm3": float(e.get("worn_mm3", 0.0)), "slidMm": float(e.get("slid_mm", 0.0)), "rubMm": float(e.get("rub_mm", 0.0)),
		"passes": int(e.get("passes", 0)), "renewed": int(e.get("renewed", 0)), "text": text,
		# el ancho de la tira de la cara que ha trabajado (mm): la que se ve gastada
		"stripMm": float(e.get("strip_mm", 0.0)),
		"source": String(CareData.TOOL_WEAR.k_mild.source) + "; " + String(CareData.TOOL_WEAR.onset.source),
	}


## Las herramientas de limar del ensayo, como van: { id: state() } de todas las que se gastan (las que no se han tocado,
## nuevas).
func view() -> Dictionary:
	var out := {}
	for id: String in CareData.TOOL_IDS:
		var t: Dictionary = CareData.TOOLS[id]
		if wears(t):
			out[id] = state(t)
	return out
