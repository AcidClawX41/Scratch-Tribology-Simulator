## Cetrería · la reacción del animal (unidad 5t-B): la fuente de DEMOSTRACIÓN de las reacciones, solo para la demo
## (demo_reaccion.gd) y los tests. El juego de verdad las recibe del estado (ClawCareState.view().animal.reaction, la
## calle C) y apunta los rayones con su orden lens_record.
## Aquí solo se elige cuándo salta (a mano, sin el estrés del animal); lo que le pasa a la lente sale del motor de verdad:
## ClawCareReaction.lens_hit (core) y el daño se guarda en una ClawCareLens (core), como en el juego.
extends RefCounted

const Reaction = preload("res://core/lab/claw_care_reaction.gd")
const Lens = preload("res://core/lab/claw_care_lens.gd")

var seq := 0
var lens: Lens = Lens.new("plastico")


## Una reacción del animal con su garra (claw, la del banco) y su material (inlay) contra la lente puesta, con intensidad.
## → el evento del contrato: { seq, warning, kind, intensity, lens }.
func event(animal: String, claw: String, inlay: String, intensity := 0.9) -> Dictionary:
	seq += 1
	var hit := Reaction.lens_hit(lens.lens_id, { "animal": animal, "claw": claw, "inlay": inlay, "intensity": intensity })
	hit["seq"] = seq
	return { "seq": seq, "warning": false, "kind": Reaction.kind_of(animal, claw), "intensity": intensity, "lens": hit, "demo": true }


## El aviso de amenaza (sin zarpazo).
func warning(animal: String, claw: String, on := true) -> Dictionary:
	return { "seq": seq, "warning": on, "kind": Reaction.kind_of(animal, claw), "intensity": 0.0, "lens": {}, "demo": true }


## Apunta en la lente lo que ha dibujado la escena (lo que hace ClawCareState.lens_record en el juego).
func record(ev: Dictionary, traces: Dictionary) -> Array:
	return lens.record(ev.get("lens", {}), traces)


## Otra lente (la tienda de la 5u, en el juego).
func mount(id: String) -> void:
	lens = Lens.new(id)
