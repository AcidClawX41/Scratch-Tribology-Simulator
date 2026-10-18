## Tribología biológica · cetrería: los minijuegos de los encargos (unidad 5v; petición de Eric del 17-10: «minijuegos de pulir,
## transformar cada garra de los animales, o reforjar el material de nuevo en la reforja, para los animales que lleguen con las
## garras rotas de serie, o que se hayan roto durante la operación»). Sin nodos, sin estado y determinista: lee la vista de la
## cetrería (ClawCareState.view(), con tip_help si la pone el hilo del estado) y dice cómo va el minijuego del encargo; no
## calcula física nueva (la rugosidad, la punta, la sangre y la rotura son las del motor).
##   - pulir: el acabado de la punta (el Ra medio de los últimos POLISH_ZONE_MM, la superficie del motor de la 5g) por debajo del
##     que pide el encargo, sin quemarla;
##   - transformar: la punta en la banda que pide (las del medidor de la 5s: roma, natural, afilada o aguja, con sus veces el
##     radio natural);
##   - reparar: la garra rota (de serie o rota durante la operación) con la sangre parada, desinfectada y reconstruida (el
##     metacrilato) o con la pieza de la reforja colocada (5o).
## Los números de los objetivos (el Ra que se pide, la banda) son del juego («juego») salvo donde dicen su fuente.
## Uso: const VetMinigames = preload("res://core/lab/vet_minigames.gd"); VetMinigames.view(job, care_view).
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")

## La parte de la punta que cuenta para el acabado (mm desde el vértice): la que toca la presa o la percha. Juego.
const POLISH_ZONE_MM := 5.0
const GAME := "juego"
const KINDS := { "pulir": "Pulir", "transformar": "Transformar la garra", "reparar": "Reparar la garra rota", "reforjar": "Reforjar la garra" }
## Las bandas del medidor que puede pedir «transformar» (veces el radio natural de la punta; las de la 5s, CareData.MARGINS):
## lo que el encargo da por bueno.
const BANDS := {
	"roma": { "lo": 2.0, "hi": 12.0, "name": "roma" },
	"natural": { "lo": 0.5, "hi": 2.0, "name": "natural" },
	"afilada": { "lo": 0.5, "hi": 1.0, "name": "afilada" },
}


## El acabado de la punta de la superficie del motor (snapshot().surface): { ra_um (medio de los últimos POLISH_ZONE_MM),
## burned (si alguna estación de ahí se ha quemado), stations }.
static func tip_surface(surface: Dictionary) -> Dictionary:
	var ra: PackedFloat64Array = surface.get("ra_um", PackedFloat64Array())
	var burn: PackedFloat64Array = surface.get("burn", PackedFloat64Array())
	var n := ra.size()
	if n == 0:
		return { "ra_um": 0.0, "burned": false, "stations": 0 }
	var st := float(surface.get("stationMm", 0.05))
	var k := clampi(int(ceilf(POLISH_ZONE_MM / maxf(st, 1e-6))), 1, n)
	var sum := 0.0
	var burned := false
	for i in range(n - k, n):
		sum += ra[i]
		if i < burn.size() and burn[i] > 0.0:
			burned = true
	return { "ra_um": sum / float(k), "burned": burned, "stations": k }


## Lo que hace falta de la vista para los encargos de la 5v (se suma a VetProgress.care_summary): los procesos del tutorial
## hechos, la punta (sus veces el natural y su aguante de lado), el acabado de la punta, la garra rota (de serie o rota en la
## operación), si está reparada y si sigue sangrando.
static func summary(v: Dictionary) -> Dictionary:
	var sn: Dictionary = v.get("snap", {})
	var tut: Dictionary = v.get("tutorial", {})
	var done: Array = []
	for p: Dictionary in tut.get("processes", []):
		if String(p.get("state", "")) == "hecho":
			done.append(String(p.id))
	if bool(tut.get("done", false)):
		for p: Dictionary in tut.get("processes", []):
			if not done.has(String(p.id)):
				done.append(String(p.id))
	var tip: Dictionary = sn.get("tip", {})
	var dmg: Dictionary = sn.get("damage", {})
	var surf := tip_surface(sn.get("surface", {}))
	var claw: Dictionary = sn.get("claw", {})
	return {
		"tut_done": done, "tip_ratio": float(tip.get("ratio", 1.0)), "tip_strength": tip.get("strengthRatio"),
		"ra_tip_um": float(surf.ra_um), "burned_tip": bool(surf.burned), "broken": bool(dmg.get("broken", false)),
		"broken_start": String(dmg.get("brokenStart", "")), "repaired": bool(dmg.get("repaired", false)),
		"overgrowth_left_mm": float(claw.get("overgrowthLeftMm", 0.0)), "over_mm": float(claw.get("startMm", 0.0)) - float(claw.get("naturalMm", 0.0)),
	}


## ¿Está la punta en la banda band (BANDS)? La aguja (menos de ¼ del aguante de lado) nunca cuenta como afilada ni natural.
static func in_band(ratio: float, strength: Variant, band: String) -> bool:
	var b: Dictionary = BANDS.get(band, BANDS.natural)
	if band != "roma" and strength != null and float(strength) < 0.25:
		return false
	return ratio >= float(b.lo) - 1e-9 and ratio <= float(b.hi) + 1e-9


## Cómo va el minijuego del encargo j con la vista v: { kind, title, goal, progress (0-1), text (lo que falta), ok, warn,
## quality }. {} si el encargo no tiene minijuego.
static func view(j: Dictionary, v: Dictionary) -> Dictionary:
	var kind := String(j.get("minigame", ""))
	if kind == "" or v.is_empty():
		return {}
	var s := summary(v)
	var out := { "kind": kind, "title": String(KINDS.get(kind, kind)), "goal": "", "progress": 0.0, "text": "", "ok": false, "warn": "",
		"quality": GAME }
	match kind:
		"pulir":
			var target := float(j.get("ra_max_um", 1.5))
			var ra := float(s.ra_tip_um)
			var left := maxf(float(s.overgrowth_left_mm), 0.0)
			var over := maxf(float(s.over_mm), 1e-6)
			var shape := clampf(1.0 - left / over, 0.0, 1.0) if over > 1e-6 else 1.0
			# el acabado, en escala logarítmica: de la lima gruesa (~10 µm) al que pide
			var fin := 1.0 if ra <= target else clampf(1.0 - V8.js_log(ra / target) / V8.js_log(10.0 / target), 0.0, 1.0)
			out["goal"] = "Punta pulida: Ra de ≤ %s µm en los últimos %s mm, sin quemarla" % [Js.to_fixed(target, 1), Js.to_fixed(POLISH_ZONE_MM, 0)]
			out["progress"] = 0.5 * shape + 0.5 * fin
			out["ok"] = ra <= target and left <= 0.1 * over + 1e-9 and not bool(s.burned_tip)
			out["text"] = "Ra en la punta: %s µm (pide ≤ %s)%s" % [Js.to_fixed(ra, 2), Js.to_fixed(target, 1),
				("; faltan %s mm de largo" % Js.to_fixed(left, 1)) if left > 0.1 * over else ""]
			if bool(s.burned_tip):
				out["warn"] = "La punta se ha quemado con el torno: hay que quitar la capa quemada (lijando) y pulir de nuevo."
		"transformar":
			var band := String(j.get("band", "natural"))
			var b: Dictionary = BANDS.get(band, BANDS.natural)
			var ratio := float(s.tip_ratio)
			var ok := in_band(ratio, s.tip_strength, band)
			var center := sqrt(float(b.lo) * float(b.hi))
			var start := float((CareData.TIP_STARTS.get(String(j.get("tip_start", "natural")), {}) as Dictionary).get("ratio", 1.0))
			var span := absf(V8.js_log(start / center))
			var dist := absf(V8.js_log(maxf(ratio, 1e-6) / center))
			out["goal"] = "La punta %s: entre ×%s y ×%s el radio natural" % [String(b.name), Js.to_fixed(float(b.lo), 1), Js.to_fixed(float(b.hi), 1)]
			out["progress"] = 1.0 if ok else clampf(1.0 - dist / maxf(span, 1e-6), 0.0, 0.95)
			out["ok"] = ok
			var passes := String((((v.get("tip_help", {}) as Dictionary).get("meter", {}) as Dictionary).get("passes", {}) as Dictionary).get("text", ""))
			out["text"] = "Punta ×%s de la natural%s" % [Js.to_fixed(ratio, 2), (" · " + passes) if passes != "" and not ok else ""]
			if band != "roma" and s.tip_strength != null and float(s.tip_strength) < 0.25:
				out["warn"] = "Ha quedado como una aguja: aguanta de lado menos de ¼ de la natural. Un toque ligero de frente le deja una cara diminuta."
		"reparar":
			var steps := [
				["sangre", "La sangre parada", not bool((v.get("snap", {}) as Dictionary).get("bleeding", {}).get("active", false))],
				["desinfectar", "Desinfectada", _disinfected(v)],
				["reparada", "Reconstruida o con la pieza de la reforja colocada", bool(s.repaired) or _bond_done(v)],
			]
			var n := 0
			var missing: Array = []
			for st: Array in steps:
				if bool(st[2]):
					n += 1
				else:
					missing.append(String(st[1]).to_lower())
			out["goal"] = "Reparar la garra rota: parar la sangre, desinfectar y reconstruirla (metacrilato) o colocarle la pieza de la reforja"
			out["progress"] = float(n) / float(steps.size())
			out["ok"] = n == steps.size()
			out["text"] = "Hecho" if missing.is_empty() else "Falta: %s" % ", ".join(missing)
		"reforjar":
			var bd: Dictionary = v.get("bond", {})
			var mats: Array = j.get("materials", [])
			var steps := [
				["pieza", "La pieza hecha en la reforja (el laboratorio experimental)", not bd.is_empty()],
				["material", "De %s" % " o ".join(mats), mats.has(String(bd.get("material", "")))],
				["colocada", "Colocada sobre el muñón", bool(bd.get("attached", false))],
				["curada", "Pegada y curada, sin escalón", bool(bd.get("done", false))],
				["probada", "Probada con un tirón suave", bool((bd.get("test", {}) as Dictionary).get("ok", false))],
			]
			var n := 0
			var missing: Array = []
			for st: Array in steps:
				if bool(st[2]):
					n += 1
				elif missing.is_empty():
					missing.append(String(st[1]))
			out["goal"] = "Reforjar la garra rota: una funda de %s hecha en la reforja y colocada a mano" % " o ".join(mats)
			out["progress"] = float(n) / float(steps.size())
			out["ok"] = n == steps.size()
			out["text"] = "Hecho" if missing.is_empty() else "Siguiente: %s" % String(missing[0]).to_lower()
	return out


static func _disinfected(v: Dictionary) -> bool:
	var bl: Dictionary = (v.get("snap", {}) as Dictionary).get("bleeding", {})
	return not bool(bl.get("bled", false)) or bool(bl.get("disinfected", false))


static func _bond_done(v: Dictionary) -> bool:
	var bd: Dictionary = v.get("bond", {})
	return not bd.is_empty() and bool(bd.get("attached", false)) and bool(bd.get("done", false))
