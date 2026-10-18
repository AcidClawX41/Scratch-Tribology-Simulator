## Tribología biológica · cetrería: el daño acumulado de una lente de la cámara (unidad 5t-A; petición 62 de Eric, 13-10-2026).
## Sin nodos, determinista y sin variables estáticas mutables.
##
## La lente puesta (una de ClawCareReaction.LENSES) guarda lo que le han hecho los zarpazos del animal:
##   - los rayones (rayón fino, rayón hondo, desgarro y grieta) se acumulan y NO se limpian: cada uno con su trazo en
##     coordenadas normalizadas de la pantalla (0-1, los pone la interfaz al proyectar la punta de cada garra sobre la
##     lente), su anchura y su hondura (las del motor: ClawCareReaction.lens_hit), su tipo, la garra que lo hizo (el dedo y
##     su material) y la reacción que lo hizo (seq);
##   - las manchas (grasa, polvo o el trazo de un metal blando) se van con el paño (clean());
##   - obscuration (0-1): cuánto se ve de menos. Es un ÍNDICE DE JUEGO, no una medida óptica: crece con el área rayada (el
##     largo de cada trazo por su anchura, de la del motor sobre el diámetro de la lente, por un halo que dispersa la luz),
##     y cada grieta tapa un círculo. 1 − e^(−área/OBSCURE_AREA).
##   - to_dict() / from_dict(): para guardarlo (la 5u guarda la lente puesta y las compradas); from_dict() tolera datos
##     viejos o rotos (se queda con lo que entiende).
## Uso: var lens := ClawCareLens.new("plastico"); lens.record(hit, { "I": [Vector2(0.2, 0.3), Vector2(0.4, 0.5)] })
extends RefCounted

const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const V8 = preload("res://core/shared/v8_math.gd")

## Versión del formato de to_dict().
const FORMAT_VERSION := 1
## Los rayones que se quedan (los de lens_hit menos la mancha y «nada»).
const SCRATCH_KINDS := ["rayon", "rayon_hondo", "desgarro", "grieta"]
## Índice de juego: el halo de un rayón (un rayón dispersa la luz más allá de su anchura), el radio de la zona que tapa una
## grieta (en la pantalla, 0-1), el área (normalizada) con la que se ve un 63 % menos y el aviso.
const HALO := 2.0
const CRACK_RADIUS := 0.12
const OBSCURE_AREA := 0.25
const WARN_OBSCURATION := 0.6
## La calidad del índice (no es una medida óptica).
const QUALITY := "juego"
const WARNING_TEXT := "La lente está tan rayada que casi no se ve: cámbiala en la tienda."
## Tope de marcas guardadas (con muchas menos, la lente ya no deja ver nada).
const MAX_MARKS := 512

## La lente (ClawCareReaction.LENS_IDS).
var lens_id := "plastico"
## [{ id, kind, trace: PackedVector2Array, widthUm, depthUm, finger, material, seq }]
var scratches: Array = []
## [{ id, trace, finger, material, transfer, seq }]
var smudges: Array = []
## Cambia con cada cambio (la escena repinta solo si cambia).
var serial := 0
var _next_id := 1


func _init(id: String = "plastico") -> void:
	reset(id)


## Una lente nueva de ese tipo (la de plástico si no existe), sin rayones ni manchas.
func reset(id: String = "plastico") -> void:
	lens_id = id if Reaction.LENSES.has(id) else "plastico"
	scratches = []
	smudges = []
	_next_id = 1
	serial += 1


## Apunta lo que ha dejado un zarpazo (el resultado de ClawCareReaction.lens_hit) con el trazo de cada garra (traces:
## { dedo: [Vector2 | [x, y], …] } en coordenadas normalizadas de la pantalla). Una garra sin trazo no se apunta. La que
## raja la lente deja su grieta (en el primer punto de su trazo) y, si además raya, su rayón. Devuelve los ids nuevos.
func record(hit: Dictionary, traces: Dictionary) -> Array:
	var ids: Array = []
	var seq := int(hit.get("seq", 0))
	for c: Variant in hit.get("claws", []):
		if not (c is Dictionary):
			continue
		var cd: Dictionary = c
		var fid := String(cd.get("finger", ""))
		if not traces.has(fid):
			continue
		var tr := _trace(traces[fid])
		if tr.is_empty():
			continue
		var outcome := String(cd.get("outcome", "nada"))
		var mat := String(cd.get("material", "none"))
		if bool(cd.get("scratched", false)):
			var kind := String(cd.get("scratch", outcome))
			if not (kind in ["rayon", "rayon_hondo", "desgarro"]):
				kind = "rayon"
			ids.append(add_scratch(kind, tr, float(cd.get("widthUm", 0.0)), float(cd.get("depthUm", 0.0)), fid, mat, seq))
		if outcome == "grieta":
			ids.append(add_scratch("grieta", PackedVector2Array([tr[0]]), 0.0, 0.0, fid, mat, seq))
		elif outcome == "mancha":
			ids.append(add_smudge(tr, fid, mat, String(cd.get("transfer", "")), seq))
	return ids.filter(func(i: int) -> bool: return i > 0)


## Un rayón que se queda (kind: SCRATCH_KINDS). Devuelve su id (0 si no cabe o no vale). id: el suyo (al recuperarlo de
## to_dict); 0, uno nuevo.
func add_scratch(kind: String, trace: Variant, width_um: float, depth_um: float, finger: String = "", material: String = "none", seq: int = 0, id: int = 0) -> int:
	var tr := _trace(trace)
	if not (kind in SCRATCH_KINDS) or tr.is_empty() or scratches.size() + smudges.size() >= MAX_MARKS:
		return 0
	id = _take_id(id)
	scratches.append({ "id": id, "kind": kind, "trace": tr, "widthUm": maxf(width_um, 0.0), "depthUm": maxf(depth_um, 0.0),
		"finger": finger, "material": material, "seq": seq })
	serial += 1
	return id


## Una mancha (grasa, polvo o el trazo de un metal blando, transfer), que se va con el paño. Devuelve su id (0 si no vale).
func add_smudge(trace: Variant, finger: String = "", material: String = "none", transfer: String = "", seq: int = 0, id: int = 0) -> int:
	var tr := _trace(trace)
	if tr.is_empty() or scratches.size() + smudges.size() >= MAX_MARKS:
		return 0
	id = _take_id(id)
	smudges.append({ "id": id, "trace": tr, "finger": finger, "material": material, "transfer": transfer, "seq": seq })
	serial += 1
	return id


## El id de una marca nueva: el pedido si es válido y no está usado; si no, el siguiente.
func _take_id(want: int) -> int:
	var used := want > 0 and (scratches.any(func(m: Dictionary) -> bool: return int(m.id) == want) or smudges.any(func(m: Dictionary) -> bool: return int(m.id) == want))
	var id := want if want > 0 and not used else _next_id
	_next_id = maxi(_next_id, id + 1)
	return id


## El paño: quita las manchas (los rayones se quedan). Devuelve cuántas ha quitado.
func clean() -> int:
	var n := smudges.size()
	if n > 0:
		smudges = []
		serial += 1
	return n


## El área rayada (normalizada a la pantalla): por cada rayón, el largo de su trazo por su anchura (la del motor sobre el
## diámetro de la ventana) por el halo; por cada grieta, el círculo que tapa.
func area() -> float:
	var d_um := 2.0 * float((Reaction.LENSES[lens_id] as Dictionary).pane.a) * 1000.0
	var a := 0.0
	for s: Dictionary in scratches:
		if String(s.kind) == "grieta":
			a += PI * CRACK_RADIUS * CRACK_RADIUS
		else:
			a += _length(s.trace) * float(s.widthUm) / d_um * HALO
	return a


## Cuánto se ve de menos (0-1, índice de juego): 1 − e^(−área/OBSCURE_AREA). Nunca baja al añadir un rayón.
func obscuration() -> float:
	return clampf(1.0 - V8.js_exp(-area() / OBSCURE_AREA), 0.0, 1.0)


## El aviso cuando casi no se ve («» si aún se ve bien).
func warning() -> String:
	return WARNING_TEXT if obscuration() >= WARN_OBSCURATION else ""


## Lo que pinta la escena (copias): { lens, lensName, level, scratches, smudges, obscuration, obscurationQuality («juego»),
## warning, serial }.
func view() -> Dictionary:
	var L: Dictionary = Reaction.LENSES[lens_id]
	return {
		"lens": lens_id, "lensName": String(L.name), "level": int(L.level), "scratches": scratches.duplicate(true),
		"smudges": smudges.duplicate(true), "obscuration": obscuration(), "obscurationQuality": QUALITY, "warning": warning(),
		"serial": serial,
	}


## Para guardarlo (ConfigFile o JSON): { version, lens, next_id, scratches, smudges }, con los trazos como [[x, y], …].
func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION, "lens": lens_id, "next_id": _next_id,
		"scratches": scratches.map(func(s: Dictionary) -> Dictionary: return _plain(s)),
		"smudges": smudges.map(func(s: Dictionary) -> Dictionary: return _plain(s)),
	}


## Lo recupera de to_dict(). Tolera datos viejos o rotos: se queda con lo que entiende (una lente desconocida es la de
## plástico; un rayón sin trazo o de un tipo que no existe, fuera). false si d no es un diccionario (queda una lente nueva).
func from_dict(d: Variant) -> bool:
	if not (d is Dictionary):
		reset("plastico")
		return false
	var dd: Dictionary = d
	reset(String(dd.get("lens", "plastico")))
	var sl: Variant = dd.get("scratches", [])
	for s: Variant in sl if sl is Array else []:
		if s is Dictionary:
			var sd: Dictionary = s
			add_scratch(String(sd.get("kind", "")), sd.get("trace", []), _num(sd.get("widthUm")), _num(sd.get("depthUm")),
				String(sd.get("finger", "")), String(sd.get("material", "none")), int(_num(sd.get("seq"))), int(_num(sd.get("id"))))
	var ml: Variant = dd.get("smudges", [])
	for s: Variant in ml if ml is Array else []:
		if s is Dictionary:
			var sd: Dictionary = s
			add_smudge(sd.get("trace", []), String(sd.get("finger", "")), String(sd.get("material", "none")),
				String(sd.get("transfer", "")), int(_num(sd.get("seq"))), int(_num(sd.get("id"))))
	_next_id = maxi(_next_id, int(_num(dd.get("next_id"))))
	serial += 1
	return true


## Un trazo limpio: puntos dentro de la pantalla (0-1), de un PackedVector2Array, de Vector2 o de pares [x, y].
static func _trace(v: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if v is PackedVector2Array:
		for p: Vector2 in v:
			out.append(Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, 1.0)))
	elif v is Array:
		for p: Variant in v:
			if p is Vector2:
				out.append(Vector2(clampf((p as Vector2).x, 0.0, 1.0), clampf((p as Vector2).y, 0.0, 1.0)))
			elif p is Array and (p as Array).size() >= 2 and _is_num((p as Array)[0]) and _is_num((p as Array)[1]):
				out.append(Vector2(clampf(float(p[0]), 0.0, 1.0), clampf(float(p[1]), 0.0, 1.0)))
	return out


## El largo de un trazo (normalizado).
static func _length(tr: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, tr.size()):
		l += tr[i].distance_to(tr[i - 1])
	return l


## Una marca para guardarla: el trazo como pares [x, y].
static func _plain(s: Dictionary) -> Dictionary:
	var out := s.duplicate(true)
	var pts: Array = []
	for p: Vector2 in (s.trace as PackedVector2Array):
		pts.append([p.x, p.y])
	out["trace"] = pts
	return out


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


static func _num(v: Variant) -> float:
	return float(v) if _is_num(v) else 0.0
