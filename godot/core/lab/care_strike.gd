## Tribología biológica · cetrería: cuánto dura y a qué velocidad llega el zarpazo del animal que se revuelve en la mesa
## (unidad 5t-B, la reacción del animal). Sin nodos, determinista y sin variables estáticas.
##
## El miembro parte del reposo empujado por la fuerza de la garra F (el «máximo esfuerzo» de la ficha del catálogo:
## zarpazo o agarre) con la masa eficaz del golpe m (`strike.m` de la ficha), a lo largo del recorrido d hasta la lente de
## la cámara. Con la fuerza constante (el trabajo F·d se va todo en energía cinética):
##   t = √(2·d·m/F)        v = √(2·F·d/m)
## El tigre y el oso dan ~7 m/s, como el `strike.v` de su ficha (8 y 7 m/s, estimaciones del catálogo); las rapaces,
## tumbadas, extienden la pata (~4-6 m/s): el `strike.v` de 12 o 40 m/s de su ficha es el de la caza en vuelo y no vale aquí.
## La garra reforjada que pesa más (ClawMass.energy_effect: el mismo trabajo mueve más masa) llega algo más tarde:
## t' = t/√(m/(m+Δm)). Solo se anima la diferencia si ClawMass dice que se nota (su criterio, `noticeable`).
## Qué no predice: la cadena de huesos y músculos del miembro (nadie ha medido su inercia segmento a segmento en estos
## animales), la fuerza que cambia a lo largo del golpe ni lo que frena el aire.
## Unidades: m · s · N · kg · m/s.
## Uso: const CareStrike = preload("res://core/lab/care_strike.gd"); CareStrike.strike("tigre", "none", 0.28, 4).
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const Js = preload("res://core/shared/js.gd")

## La fuente del modelo (texto legible para la interfaz).
const SOURCE := "Trabajo y energía con la fuerza constante (t = √(2·d·m/F)): la fuerza de la garra (máximo esfuerzo) y la masa eficaz del golpe de la ficha del catálogo, estimaciones (core/lab/data.gd; el velocirraptor, core/lab/velociraptor.gd); el recorrido hasta la lente es del dibujo del plano"
## Recorrido mínimo y máximo que se acepta (m): por debajo, el golpe no tiene sentido; por encima, se acota.
const TRAVEL_MIN := 0.02
const TRAVEL_MAX := 1.5


## El golpe de la garra claw_id (Data.CLAWS o «velociraptor») con la garra de inlay («none»: queratina; Data.INLAYS o los de
## la 2.0) a lo largo de travel_m, con n_claws garras en la mano o el pie que golpea.
## → { ok, forceN, massKg, travelM, tS, vMs, energyJ, inlay, addedKg, tClawS, vClawS, appreciable, quality, source, note }
##   (tClawS y vClawS: con la masa de la garra reforjada; appreciable: si ClawMass dice que se nota). ok = false sin ficha.
static func strike(claw_id: String, inlay: String, travel_m: float, n_claws: int = 4) -> Dictionary:
	var e := CareData.claw_entry(claw_id)
	var s: Variant = e.get("strike")
	if e.is_empty() or not (s is Dictionary) or float(e.get("force", 0.0)) <= 0.0 or float((s as Dictionary).get("m", 0.0)) <= 0.0:
		return { "ok": false, "note": "sin la fuerza o la masa del golpe en la ficha de «%s»" % claw_id }
	var f := float(e.force)
	var m := float((s as Dictionary).m)
	var d := clampf(travel_m, TRAVEL_MIN, TRAVEL_MAX)
	var t := sqrt(2.0 * d * m / f)
	var v := sqrt(2.0 * f * d / m)
	var out := {
		"ok": true, "forceN": f, "massKg": m, "travelM": d, "tS": t, "vMs": v, "energyJ": f * d, "inlay": inlay,
		"addedKg": 0.0, "tClawS": t, "vClawS": v, "appreciable": false, "quality": "estimate", "source": SOURCE, "note": "",
	}
	if inlay == "" or inlay == "none":
		return out
	var vol := ClawMass.cone_volume_mm3(float(e.get("reach", 0.0)))
	var eff: Variant = ClawMass.energy_effect(inlay, vol, maxi(n_claws, 1), float(e.get("mass", 0.0)), m, v)
	if not (eff is Dictionary):
		out["note"] = "sin la densidad de «%s»: el golpe, el de la queratina" % inlay
		return out
	var ratio := float(eff.sameWorkSpeed)
	out["addedKg"] = float(eff.addedKg)
	if ratio > 0.0:
		out["vClawS"] = v * ratio
		out["tClawS"] = t / ratio
	out["appreciable"] = bool(eff.noticeable)
	out["note"] = "la garra de %s pesa %s g más que la de queratina: %s" % [inlay, Js.to_fixed((float(eff.clawKg) - float(eff.keratinKg)) * 1000.0, 1),
		"el golpe cambia" if bool(eff.noticeable) else "no se nota en el golpe"]
	return out
