## Ilustración de una garra en las fichas y en la comparativa del laboratorio, con el velocirraptor reconstruido de la
## 2.0 (core/lab/art_dino.gd, unidad 4i): su garra falciforme con el hueso fósil, el estuche de queratina y su banda. Las
## demás garras, colmillos y aguijones, las de siempre (LabUi.show_claw). Solo pinta: los dibujos son funciones puras del
## core que ArtCache rasteriza en hilos.
## Uso: const DinoViews = preload("res://app/lab/dino_views.gd"); DinoViews.show_claw(vista, caché, garra, material, uid)
extends RefCounted

const ArtDino = preload("res://core/lab/art_dino.gd")
const DinoLab = preload("res://core/lab/dino_lab.gd")
const Catalog = preload("res://core/lab/catalog.gd")
const LabUi = preload("res://app/lab/lab_ui.gd")
const ArtView = preload("res://app/common/art_view.gd")
const ArtCache = preload("res://app/common/art_cache.gd")


## Garra, colmillo o aguijón en una vista de ficha (100 × 132). detail: en la ficha de la herramienta, la lupa de los
## aguijones o, en el velocirraptor, los rótulos (la sección de la base y el «?» de la punta sin medir).
static func show_claw(v: ArtView, cache: ArtCache, claw: Dictionary, inlay: Variant, uid: String, tip_color: Variant = null,
		detail := false) -> void:
	if not DinoLab.is_dino(claw):
		LabUi.show_claw(v, cache, claw, inlay, uid, tip_color, detail)
		return
	var key := "dino:%s:%s:%s:%s:%s" % [uid, claw.id, inlay.id if inlay != null else "-", tip_color, detail]
	var o := { "inlay": inlay, "tipColor": tip_color, "uid": uid, "labels": detail }
	v.set_art(cache, key, ArtDino.claw_icon_art.bind(claw, o), LabUi.CLAW_VIEW, null if detail else [])
	v.accessibility_name = Catalog.claw_title(claw)
