## Tablas de dibujo del laboratorio: port literal de las de packages/core/src/art.js (1.x), con las mismas claves y
## valores. Solo describen el aspecto (colores, texturas, rasgos de cada animal); no hay física.
##
## Al final van, con los nombres que usa el dibujo, las tablas de data.js y theme.js que necesita (capas de pintura
## y de piel, carrocerías, paleta). No son copias: apuntan a core/lab/data.gd y a core/shared/theme.gd.
## Uso: const Looks = preload("res://core/lab/looks.gd"), y después Looks.MATERIAL_LOOK["madera"].
extends RefCounted

## Aspecto de cada material: tipo de textura (kind), color base y de sombra, y detalles (vetas, escamas…).
const MATERIAL_LOOK := {
	"piel": { "kind": "skin", "base": "#EFC3A6", "lo": "#D9977B", "ink": "#B8735B" },
	"madera": { "kind": "wood", "base": "#E6C08A", "lo": "#C8985C", "ink": "#9C6C37", "knot": true },
	"puertamadera": { "kind": "wood", "base": "#A36E40", "lo": "#6B4222", "ink": "#43260F", "lacquer": true },
	"puertametal": { "kind": "brushed", "base": "#D0D6DD", "lo": "#98A1AB" },
	"una": { "kind": "keratin", "base": "#F6D8D4", "lo": "#E4B6B2" },
	"plastico": { "kind": "plastic", "base": "#667688", "lo": "#465261" },
	"coche": { "kind": "paint", "base": "#A1263C", "lo": "#560F1F", "flake": "#FFB3C1" },
	"cocheclasico": { "kind": "paint", "base": "#2F6B57", "lo": "#163B30", "flake": null },  # esmalte liso de época
	"cochealu": { "kind": "paint", "base": "#8FA8C2", "lo": "#4B6078", "flake": "#FFFFFF" },  # gris azulado metalizado
	"cocheplastico": { "kind": "paint", "base": "#ECEAE4", "lo": "#B9B6AE", "flake": "#FFFFFF" },  # blanco nacarado
	"cobre": { "kind": "copper", "base": "#E7A064", "lo": "#9C5426", "ink": "#5E8C6A" },
	"vidrio": { "kind": "glass", "base": "#CBF1EC", "lo": "#86CBC6" },
	"acero": { "kind": "brushed", "base": "#CBD2DA", "lo": "#8B95A1", "tint": "#AFC6DB" },
	"movil": { "kind": "screen", "base": "#27303F", "lo": "#0B1018" },
	"cuarzo": {
		"kind": "stone", "base": "#EEE8DF", "lo": "#D3CABC",
		"flecks": ["#8E867B", "#655F58", "#C9BBA3", "#FFFFFF", "#AFA597"],
	},
	"zafiro": { "kind": "crystal", "base": "#8CBDF0", "lo": "#2F58A0" },
	"diamante": { "kind": "diamond", "base": "#F1F7FF", "lo": "#BFD1EA" },
	# capas de los cortes (pintura OEM y puerta)
	"capa-barniz": { "kind": "clear", "base": "#E2F3F8", "lo": "#B4D6E3" },
	"capa-color": { "kind": "paint", "base": "#A1263C", "lo": "#6A1426", "flake": "#FFB3C1" },
	"capa-imprimacion": { "kind": "matte", "base": "#B6BBC0", "lo": "#979DA4" },
	"capa-anticorrosivo": { "kind": "matte", "base": "#5C6854", "lo": "#434C3D" },
	# carrocerías (corte de capas del coche)
	"capa-acero-bh": { "kind": "brushed", "base": "#C3CAD2", "lo": "#8C95A0" },
	"capa-acero-dulce": { "kind": "brushed", "base": "#B4BBC3", "lo": "#7A838D" },
	"capa-aluminio": { "kind": "brushed", "base": "#DDE3EA", "lo": "#A7B1BD" },
	"capa-plastico-carroceria": { "kind": "plastic", "base": "#43484F", "lo": "#26292E" },
	"capa-laca": { "kind": "lacquer", "base": "#DDAE5B", "lo": "#B7822F" },
	"capa-roble": { "kind": "wood", "base": "#A36E40", "lo": "#6B4222", "ink": "#43260F" },
	# capas de la piel (corte de tejido)
	"tejido-cornea": { "kind": "cornea", "base": "#F6E7D8", "lo": "#E9CFB9" },
	"tejido-epidermis": { "kind": "cells", "base": "#EDBBA2", "lo": "#DB9C82", "ink": "#B8735B" },
	"tejido-dermis": { "kind": "collagen", "base": "#E0A09A", "lo": "#C57872", "ink": "#9E4B4B", "vessel": "#C2303A" },
	"tejido-grasa": { "kind": "fat", "base": "#F3D98A", "lo": "#E0B95A", "ink": "#C9A04A" },
	"tejido-fascia": { "kind": "fascia", "base": "#ECEEF3", "lo": "#C9CDD8" },
	"tejido-musculo": { "kind": "muscle", "base": "#B23F48", "lo": "#7E232C", "ink": "#5E1720" },
}
## Aspecto de cada capa de la piel (los ids coinciden con SKIN_LAYERS).
const SKIN_LAYER_LOOK := {
	"cornea": "tejido-cornea", "epidermis": "tejido-epidermis", "dermis": "tejido-dermis", "grasa": "tejido-grasa",
	"fascia": "tejido-fascia", "musculo": "tejido-musculo",
}
## Aspecto de cada capa de pintura (los ids coinciden con PAINT_LAYERS).
const PAINT_LAYER_LOOK := {
	"barniz": "capa-barniz", "color": "capa-color", "imprimacion": "capa-imprimacion", "anticorrosivo": "capa-anticorrosivo",
}
## Aspecto de cada carrocería (los ids coinciden con CAR_BODIES[…].id).
const BODY_LOOK := {
	"acero-bh": "capa-acero-bh", "acero-dulce": "capa-acero-dulce", "aluminio": "capa-aluminio",
	"plastico-carroceria": "capa-plastico-carroceria",
}

## Texturas que se astillan (vidrio, pantalla, piedra, cristal, diamante) y las metálicas.
const BRITTLE := ["glass", "screen", "stone", "crystal", "diamond"]
const METALLIC := ["brushed", "copper"]
## Incrustaciones metálicas: se pintan como tachuela pulida, no como gema tallada.
const METAL_INLAYS := ["oro", "acero", "titanio", "tungsteno", "hematites"]

## Lienzos de los cortes del coche y de la piel (300 × 164).
const CAR_SECTION := { "w": 300, "h": 164 }
const SKIN_SECTION := { "w": 300, "h": 164 }
## Alto de cada banda del corte de piel (fijo, para que se vean también las capas finas).
const SKIN_BAND := { "cornea": 9.0, "epidermis": 12.0, "dermis": 34.0, "grasa": 40.0, "fascia": 8.0, "musculo": 49.0 }

## Uña vista de frente: colores de la placa, borde libre y detalles de cada material.
const NAIL_LOOK := {
	"natural": { "bed": ["#F4BFC5", "#E8A1AB"], "edge": "#FBF2E8", "edgeOp": 0.92, "lunula": true, "ridges": true },
	"gel": { "bed": ["#E4588E", "#A8235A"], "edge": "#D9477F", "edgeOp": 1.0, "gloss": 0.7 },
	"acrilico": { "bed": ["#F3CDCB", "#E2AEAB"], "edge": "#F6DAD6", "edgeOp": 1.0, "gloss": 0.55 },
	# experimentos: uñas macizas
	"metal": { "bed": ["#E4E9EE", "#8D97A2"], "edge": "#C9D0D8", "edgeOp": 1.0, "gloss": 0.8, "brushed": true },
	"titanio": { "bed": ["#B9B3D6", "#6F7E9C"], "edge": "#A8A6C8", "edgeOp": 1.0, "gloss": 0.65, "brushed": true },
	"zafiro": { "bed": ["#8EC2F4", "#2A5AA8"], "edge": "#6FA6E6", "edgeOp": 0.9, "gloss": 0.9, "facets": true },
	"diamante": {
		"bed": ["#FFFFFF", "#C9D9EE"], "edge": "#EEF5FF", "edgeOp": 0.9, "gloss": 0.95, "facets": true, "sparkles": true,
	},
}

## Rasgos visuales de cada animal (solo dibujo): base del dedo, pelaje, escamas o encía. w0: semiancho de la
## garra en su raíz (unidades del lienzo de la garra, antes de escalar).
const CLAW_ART := {
	"gato": { "kind": "mammal", "toe": "#CFB38E", "fur": ["#EAD7B8", "#A98A64", "#6E5A45"], "w0": 10.0, "ivory": true },
	"tigre": {
		"kind": "mammal", "toe": "#E39B45", "fur": ["#F4BA68", "#C57A2D", "#221812"], "stripes": true, "w0": 12.0,
		"ivory": true,
	},
	"oso": { "kind": "mammal", "toe": "#5C4433", "fur": ["#80614A", "#4A3527", "#2A1F18"], "w0": 15.0 },
	"aguila": { "kind": "raptor", "toe": "#E2B73F", "w0": 12.5 },
	"arpia": { "kind": "raptor", "toe": "#E1B23B", "w0": 13.5 },
	"halcon": { "kind": "raptor", "toe": "#E8C44B", "w0": 10.5 },
	"buho": { "kind": "owl", "toe": "#CDB690", "w0": 11.0 },
	"lechuza": { "kind": "owl", "toe": "#EEE0C8", "w0": 8.5 },
	"buitre": { "kind": "scaly", "toe": "#908D88", "w0": 13.0 },
	"casuario": { "kind": "scaly", "toe": "#7F8FA6", "w0": 12.0 },
	"emu": { "kind": "scaly", "toe": "#71685D", "w0": 12.5 },
	"avestruz": { "kind": "scaly", "toe": "#C9A89A", "w0": 17.0 },
	"gallo": { "kind": "scaly", "toe": "#E3A74C", "w0": 12.0 },
	"guacamayo": { "kind": "scaly", "toe": "#908D8B", "w0": 9.0 },
	"pajaro": { "kind": "scaly", "toe": "#B59F88", "w0": 7.0 },
	"vibora": { "kind": "fang", "toe": "#EAA7AA", "jaw": "#8E7B58", "w0": 5.2 },
	"gabon": { "kind": "fang", "toe": "#E9A2A6", "jaw": "#B99D6D", "w0": 6.2 },
}
## Rasgos de un animal que no está en CLAW_ART (dedo escamoso gris).
const CLAW_ART_DEFAULT := { "kind": "scaly", "toe": "#999999", "w0": 6.0 }

# ── Tablas de data.js y theme.js que usa el dibujo (las mismas de la física, sin copiarlas) ──

const Data = preload("res://core/lab/data.gd")

## Capas de la pintura OEM de un coche (µm acumuladas).
const PAINT_LAYERS := Data.PAINT_LAYERS
## Capas de la piel (µm acumuladas); el corte usa ids, nombres y profundidades.
const SKIN_LAYERS := Data.SKIN_LAYERS
## Carrocería de cada coche (los materiales con `body` en TARGETS), por id del material.
const CAR_BODY := {
	"coche": Data.CAR_BODIES["moderno"],
	"cocheclasico": Data.CAR_BODIES["clasico"],
	"cochealu": Data.CAR_BODIES["aluminio"],
	"cocheplastico": Data.CAR_BODIES["plastico"],
}
## Paleta glam-lab (theme.js): los rótulos de los cortes usan text, dim, dimmer, line2 y bg.
const C := Data.C
