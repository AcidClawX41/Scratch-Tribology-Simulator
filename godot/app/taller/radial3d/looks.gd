## Aspecto de las piezas de la escena de la radial: discos, chapas pintadas y colores de revenido.
##
## Solo dibujo (como MATERIAL_LOOK de art.js): no calcula física. Los colores de la pintura y de las carrocerías
## son los del laboratorio de la 1.x (packages/core/src/data.js → PAINT_LAYERS, CAR_BODIES; art.js →
## MATERIAL_LOOK, BODY_LOOK, PAINT_LAYER_LOOK), copiados aquí hasta que exista su port en core/lab/.
## PROVISIONAL: los espesores de chapa y las medidas y velocidades máximas de los discos deben leerse, en la
## integración, de core/taller/panels.gd y core/taller/abrasives.gd (unidad 6).
extends RefCounted

const Panels = preload("res://core/taller/panels.gd")
const Abrasives = preload("res://core/taller/abrasives.gd")

## Pintura OEM (µm acumulados desde fuera): barniz 0-45, color 45-60, imprimación 60-85, anticorrosivo 85-110
## (data.js → PAINT_LAYERS). Por dentro, la chapa metálica lleva solo el anticorrosivo (cataforesis) de 25 µm.
const PAINT_LAYERS_UM := [45.0, 60.0, 85.0, 110.0]
const INNER_ECOAT_UM := 25.0

## Capas de pintura (art.js → MATERIAL_LOOK «capa-*» y data.js → PAINT_LAYERS[].col).
const CLEAR := "#E2F3F8"
const CLEAR_EDGE := "#AED2E0"
const PRIMER := "#B6BBC0"
const ECOAT := "#5C6854"

## Coches del laboratorio (MATERIAL_LOOK): color de la pintura por carrocería.
const CAR_PAINT := {
	"coche": {"base": "#A1263C", "lo": "#560F1F", "flake": "#FFB3C1", "name": "Coche moderno"},
	"cocheclasico": {"base": "#2F6B57", "lo": "#163B30", "flake": "", "name": "Coche clásico"},
	"cochealu": {"base": "#8FA8C2", "lo": "#4B6078", "flake": "#FFFFFF", "name": "Coche de aluminio"},
	"cocheplastico": {"base": "#ECEAE4", "lo": "#B9B6AE", "flake": "#FFFFFF", "name": "Aleta de plástico"},
}

## Chapas de la radial: solo el aspecto (colores de BODY_LOOK de art.js, coche y pieza que se dibujan). El espesor y
## el tipo de material son los del modelo de corte (core/taller/panels.gd, con sus fuentes): panel() los añade.
const PANELS := {
	"acero-dulce": {
		"name": "Acero dulce (DC04)", "short": "acero dulce",
		"metal": "#B4BBC3", "metal_lo": "#7A838D", "car": "cocheclasico", "part": "puerta",
	},
	"acero-bh": {
		"name": "Acero de horno (HC180B)", "short": "acero BH",
		"metal": "#C3CAD2", "metal_lo": "#8C95A0", "car": "coche", "part": "puerta",
	},
	"aluminio": {
		"name": "Aluminio AA6016", "short": "aluminio",
		"metal": "#DDE3EA", "metal_lo": "#A7B1BD", "car": "cochealu", "part": "puerta",
	},
	"plastico-carroceria": {
		"name": "Termoplástico PPE/PA", "short": "plástico PPE/PA",
		"metal": "#43484F", "metal_lo": "#26292E", "car": "cocheplastico", "part": "aleta",
	},
	"boro-22mnb5": {
		"name": "Acero al boro 22MnB5 templado", "short": "acero al boro",
		"metal": "#A9AFB6", "metal_lo": "#737B84", "car": "coche", "part": "pilar B",
	},
	"dp800": {
		"name": "Acero de fase dual DP800", "short": "DP800",
		"metal": "#BAC1C9", "metal_lo": "#838C96", "car": "coche", "part": "larguero",
	},
	"perfil-aluminio": {
		"name": "Perfil de aluminio EN AW-6082 T6", "short": "perfil de aluminio",
		"metal": "#D3D9E0", "metal_lo": "#9AA4B0", "car": "cochealu", "part": "perfil",
	},
}

## Discos: aspecto y medidas para dibujarlos. El espesor de los discos de corte es el del modelo
## (core/taller/abrasives.gd): disc() lo pone encima; aquí queda el del cuerpo de láminas, que no corta.
## max_vs: velocidad máxima de trabajo (m/s) y su franja de color de
## EN 12413 (aglomerados), EN 13743 (láminas, abrasivo aplicado) y EN 13236 (diamante): 50 azul · 63 amarillo ·
## 80 rojo · 100 verde (Klingspor, «Maximum operating speed»).
const DISCS := {
	"fino_1mm": {
		"name": "Disco de corte fino (Al2O3, 1 mm)", "short": "fino 1 mm", "kind": "abrasivo", "t_mm": 1.0,
		"body": "#4A3A32", "body_lo": "#2C221D", "label": "#E8E4DA", "label_ink": "#2B2F36", "max_vs": 80.0,
	},
	"grueso_3mm": {
		"name": "Disco de corte grueso (Al2O3, 3 mm)", "short": "grueso 3 mm", "kind": "abrasivo", "t_mm": 3.0,
		"body": "#3C3A3A", "body_lo": "#1F1E1E", "label": "#F2C94C", "label_ink": "#2B2F36", "max_vs": 80.0,
	},
	"diamante": {
		"name": "Disco de diamante segmentado", "short": "diamante", "kind": "diamante", "t_mm": 2.2,
		"core_t_mm": 1.6, "segment_mm": 8.0, "segments": 12,
		"body": "#9BA3AC", "body_lo": "#5E666F", "label": "#C8CDD3", "label_ink": "#2B2F36", "max_vs": 80.0,
	},
	"laminas": {
		"name": "Disco de láminas (circonio)", "short": "láminas", "kind": "laminas", "t_mm": 10.0,
		"flaps": 72, "body": "#3E4A66", "body_lo": "#252C3E", "label": "#1E1F24", "label_ink": "#E8E4DA", "max_vs": 80.0,
	},
	# Borde continuo de grano sobre un cuerpo de acero (unidad 1h): el espesor del borde y el del cuerpo del de metal duro
	# son los del modelo (abrasives.gd); el ancho del borde y el cuerpo del de CBN son de dibujo.
	"metal_duro": {
		"name": "Disco de grano de metal duro (1,9 mm)", "short": "metal duro", "kind": "borde", "t_mm": 1.905,
		"core_t_mm": 1.143, "segment_mm": 4.0, "rim": "#6E737A",
		"body": "#8E969F", "body_lo": "#5A626B", "label": "#E0A83A", "label_ink": "#2B2F36", "max_vs": 80.0,
	},
	"cbn_1mm": {
		"name": "Disco de CBN 1A1R (1,0 mm, para tronzadora fija)", "short": "CBN", "kind": "borde", "t_mm": 1.0,
		"core_t_mm": 0.8, "segment_mm": 5.0, "rim": "#5A3F22",
		"body": "#A7AEB6", "body_lo": "#6B737C", "label": "#D8DCE0", "label_ink": "#2B2F36", "max_vs": 50.0,
	},
}

## Franja de velocidad máxima (EN 12413).
const SPEED_STRIPES := [[50.0, "#2F6FD6"], [63.0, "#F2C230"], [80.0, "#D6333A"], [100.0, "#3BA55C"]]

## Colores de revenido del acero, TM 9-237 (1967), apéndice, tabla IV «Temper and heat colors» (°F → °C):
## paja clara 204 · paja 227 · paja oscura 238 · paja muy oscura 249 · marrón amarillento 260 · bronce 271 ·
## púrpura pleno 282 · púrpura azulado 288 · azul 299 · azul pleno 310 · azul muy oscuro 316 · azul claro 338.
## El RGB de cada nombre es una ESTIMACIÓN para pantalla; por encima de ~350 °C la capa de óxido pasa a gris.
const TEMPER_COLORS := [
	[150.0, "#00000000"],
	[204.0, "#E6D8A6"],
	[227.0, "#D9B45A"],
	[238.0, "#C99A3E"],
	[249.0, "#B8822F"],
	[260.0, "#9E6A2A"],
	[271.0, "#7E4638"],
	[282.0, "#6A3470"],
	[288.0, "#4E3A8C"],
	[299.0, "#2E4C9E"],
	[310.0, "#2D5DAF"],
	[316.0, "#243E7E"],
	[338.0, "#7A9CC0"],
	[380.0, "#8C9298"],
	[450.0, "#5E6166"],
]
## Rango de la rampa de revenido que se pasa al shader (°C).
const TEMPER_MIN_C := 150.0
const TEMPER_MAX_C := 450.0


## Aspecto de una chapa con su espesor, su tipo de material y su pintura (paint_um, µm; 0 en las piezas de rescate,
## que son acero desnudo), que son los del modelo de corte (una sola fuente).
static func panel(panel_id: String) -> Dictionary:
	var id := panel_id if PANELS.has(panel_id) else "acero-dulce"
	var look: Dictionary = (PANELS[id] as Dictionary).duplicate()
	var phys := Panels.get_panel(id)
	look["t_mm"] = float(phys["t_mm"])
	look["kind"] = String(phys["kind"])
	look["paint_um"] = float(phys.get("paint_um", 0.0))
	return look


## Aspecto de un disco; el espesor de los que cortan es el del modelo (abrasives.gd).
static func disc(disc_id: String) -> Dictionary:
	var id := disc_id if DISCS.has(disc_id) else "fino_1mm"
	var look: Dictionary = (DISCS[id] as Dictionary).duplicate()
	var phys: Dictionary = Abrasives.DISCS.get(id, {})
	if float(phys.get("thickness_mm", 0.0)) > 0.0:
		look["t_mm"] = float(phys["thickness_mm"])
	if float(phys.get("body_thickness_mm", 0.0)) > 0.0:
		look["core_t_mm"] = float(phys["body_thickness_mm"])
	return look


static func car_paint(panel_id: String) -> Dictionary:
	return CAR_PAINT[str(panel(panel_id)["car"])]


## Color de la franja de velocidad para una velocidad máxima (m/s).
static func stripe_color(max_vs: float) -> Color:
	var best: Array = SPEED_STRIPES[0]
	for s in SPEED_STRIPES:
		if absf(float(s[0]) - max_vs) < absf(float(best[0]) - max_vs):
			best = s
	return Color(str(best[1]))


## Color de revenido a t °C (interpolado en la tabla IV del TM 9-237; alfa 0 donde aún no hay color).
static func temper_color(temp_c: float) -> Color:
	var prev: Array = TEMPER_COLORS[0]
	if temp_c <= float(prev[0]):
		return Color(str(prev[1]))
	for i in range(1, TEMPER_COLORS.size()):
		var row: Array = TEMPER_COLORS[i]
		if temp_c <= float(row[0]):
			var k := (temp_c - float(prev[0])) / (float(row[0]) - float(prev[0]))
			return Color(str(prev[1])).lerp(Color(str(row[1])), k)
		prev = row
	return Color(str(prev[1]))


## Rampa de revenido de TEMPER_MIN_C a TEMPER_MAX_C para el shader de la chapa.
static func temper_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for row in TEMPER_COLORS:
		offsets.append((float(row[0]) - TEMPER_MIN_C) / (TEMPER_MAX_C - TEMPER_MIN_C))
		colors.append(Color(str(row[1])))
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex
