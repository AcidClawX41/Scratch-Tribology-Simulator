## Tarjeta 2 · Material a rayar (TargetCard de la 1.x): una ficha por material con su textura real, su nombre y su
## dureza (o qué hay bajo la pintura). La ayuda emergente enseña la ficha del material (su `fact`).
## Con la piel y la física 2.0, la zona del cuerpo (core/lab/zones.gd; docs/fisica/pulido-biologia.md §9.1): el brazo
## de la 1.x por defecto, la palma, el dorso de la mano, el pómulo o el abdomen, con su ficha debajo.
extends "res://app/common/card.gd"

const Catalog = preload("res://core/lab/catalog.gd")
const Lab = preload("res://core/lab/lab.gd")
const LabState = preload("res://core/lab/lab_state.gd")
const Physics = preload("res://core/lab/physics.gd")
const Zones = preload("res://core/lab/zones.gd")
const ArtCache = preload("res://app/common/art_cache.gd")
const ContentButton = preload("res://app/common/content_button.gd")
const Pill = preload("res://app/common/pill.gd")
const TileGrid = preload("res://app/common/tile_grid.gd")
const LabUi = preload("res://app/lab/lab_ui.gd")

var lab: LabState
var art: ArtCache
var tiles := {}  # id → ContentButton
## Zona del cuerpo (2.0, solo con la piel): una píldora por zona y la ficha de la elegida.
var zone_box: VBoxContainer
var zone_pills := {}  # id de zones.gd → Pill
var zone_note: Label


func _init() -> void:
	super("Material a rayar", "2")
	var grid := TileGrid.new(128.0)
	for t: Dictionary in Catalog.TARGETS:
		var b := LabUi.tile(Vector2(0, 34), String(t.name), Lab.target_sub(t), String(t.fact))
		grid.add_child(b)
		tiles[t.id] = b
	body.add_child(grid)
	zone_box = Ui.vbox(8)
	zone_box.add_child(Ui.sub_label("Zona del cuerpo"))
	var row := Ui.flow(7, 7)
	for z: Dictionary in Zones.ZONES:
		var p := Pill.new(String(z.short))
		p.tooltip_text = "%s\n%s" % [z.name, z.site]
		row.add_child(p)
		zone_pills[z.id] = p
	zone_box.add_child(row)
	zone_note = Ui.para("", "Note")
	zone_box.add_child(zone_note)
	zone_box.visible = false
	body.add_child(zone_box)


func setup(p_lab: LabState, p_art: ArtCache) -> void:
	lab = p_lab
	art = p_art
	for id: String in tiles:
		(tiles[id] as Button).pressed.connect(_on_pick.bind(id))
		LabUi.show_swatch(LabUi.tile_art(tiles[id]), art, Catalog.find_by_id(Catalog.TARGETS, id))
	for id: String in zone_pills:
		(zone_pills[id] as Button).pressed.connect(_on_zone.bind(id))


func _on_pick(id: String) -> void:
	if lab.target.id == id:
		refresh()
		return
	lab.set_target(Catalog.find_by_id(Catalog.TARGETS, id))


func _on_zone(id: String) -> void:
	if lab.zone == id:
		refresh()
		return
	lab.set_zone(id)


## ¿Se elige zona? Con la piel y la física 2.0 (la 1.x solo tiene el brazo).
func zone_shown() -> bool:
	return Physics.truthy(lab.target.get("skin")) and lab.model == Physics.MODEL_V2


func refresh() -> void:
	for id: String in tiles:
		(tiles[id] as ContentButton).set_on(id == lab.target.id)
	var shown := zone_shown()
	zone_box.visible = shown
	if shown:
		for id: String in zone_pills:
			(zone_pills[id] as Pill).set_on(id == lab.zone)
		var z: Dictionary = lab.zone_info()
		zone_note.text = "%s: %s" % [z.name, z.fact]
