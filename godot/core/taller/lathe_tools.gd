## Taller · herramientas de torno: plaquitas ISO 1832 y portaherramientas de Sandvik Coromant.
##
## Una herramienta es un portaherramientas (ángulo de posición κr y cotas del catálogo) con una plaquita (forma ISO
## 1832 con su ángulo de punta εr, tamaño, radio de punta rε y datos de corte recomendados). De ahí sale todo lo demás:
##   - κr' = 180° − κr − εr: ángulo de posición del filo secundario, el que va detrás de la punta al cilindrar.
##   - Ángulo máximo de copiado (rampa que baja hacia el plato) = κr' − 2°: Sandvik exige al menos 2° de ángulo libre
##     entre la pieza y la plaquita (y recomienda 7°). Si se baja más inclinado, el filo secundario talona.
##   - La envolvente de corte (lo que arranca la plaquita en cada vuelta): el círculo de la punta, de radio rε y centro
##     en la punta teórica + (rε, rε), y los dos filos rectos tangentes a él hasta su longitud útil.
##   - Un polígono simplificado del portaherramientas para las colisiones. Es una estimación: el catálogo solo da las
##     cotas B, H, LF, WF y el voladizo; la forma de la cabeza no se publica.
##   - El código de forma de la punta (location) y el centro de la punta respecto a la punta teórica (center), como
##     los usa la compensación G41/G42 del Fagor 8055 T (manual de programación, 8.2.1, p. 129-130): F3 en las de
##     torneado exterior (centro en (rε, rε)) y F62 en la de roscar (punta en el eje de la V: centro en (0, rε)).
## Coordenadas de herramienta: (dz, dr) respecto a la punta teórica, con dz hacia el contrapunto y dr hacia fuera.
## Uso: const LatheTools = preload("res://core/taller/lathe_tools.gd"); var t := LatheTools.tool(LatheTools.ROUGH)
extends RefCounted

const Js = preload("res://core/shared/js.gd")

const SRC_ISO := "ISO 1832:2017, designación de plaquitas intercambiables; clave de códigos en Sandvik Coromant, «Turning tools 2015», págs. I14–I16"
const SRC_CUT := "Sandvik Coromant, «Turning tools 2015», tabla «Recommended depth of cut and cutting feed, metric»"
const SRC_HOLDER := "Sandvik Coromant, «Turning tools 2015», capítulo A (portaherramientas de mango 25 × 25): KAPR, B, H, LF, WF y OHX"
const SRC_FREE := "Sandvik Coromant, «Internal turning» (torneado de perfiles): «a free cutting angle of at least 2° between workpiece and insert has to be maintained… at least 7° is recommended»"
const SRC_SEAT := "Sandvik Coromant, «How to choose correct turning insert»: la plaquita negativa (0°) se inclina en el asiento para tener incidencia"
const SRC_THREAD := "Sandvik Coromant, CoroThread 266, «Metric 60° Full form», plaquitas exteriores a derechas: 266RG-16MM01A250M, TP 2,5, HA 1,87, HB 0,36, ISO 965-1998 clase 6"
const SRC_THREAD_HOLDER := "Sandvik Coromant 266RFG-2525-16 (fichas de distribuidores): mango 25 × 25, longitud 150 mm, cabeza de 22,2 mm y 32 mm de la cara trasera del mango al filo"
const SRC_ISO68 := "ISO 68-1: perfil básico de la rosca métrica ISO, H = 0,866·P y radio de fondo H/6 (0,361 mm con P 2,5)"
const SRC_LOCATION := "Fagor Automation, CNC 8055 ·T· Programming manual, Ref. 1110, 8.2.1 (p. 129-130): códigos de forma F de la tabla de correctores"

const FREE_ANGLE_MIN_DEG := 2.0  # ángulo libre mínimo entre pieza y plaquita (Sandvik)
const FREE_ANGLE_REC_DEG := 7.0  # recomendado para acabado y vida de la herramienta (Sandvik)
## Material de las plaquitas para el modelo de corte (core/taller/cutting.gd, catálogo tool_materials.gd). Las
## geometrías -PF, -PM y -PR del catálogo se sirven en calidades de metal duro con recubrimiento CVD para acero
## (GC4315, GC4325…, grupo P de ISO 513): el simulador monta esa calidad en todas. Otra calidad (cermet, cerámica,
## CBN) sería otro tool_material del catálogo de corte.
const INSERT_TOOL_MATERIAL := "hm_coated"
const SRC_GRADE := "Sandvik Coromant, «Turning tools 2015»: plaquitas T-Max P -PF/-PM/-PR en calidades GC43xx (metal duro con recubrimiento CVD, ISO P)"
const NEG_SEAT_CLEARANCE_DEG := 6.0  # incidencia efectiva de una plaquita negativa en su asiento (estimación, ver fuentes-u3)
const HEAD_H_MM := 25.0  # altura de la cabeza del portaherramientas sobre la punta antes del mango (estimación)
const HOLDER_BOTTOM_EXTRA_DEG := 10.0  # la cara inferior de la cabeza sube 10° más que el filo secundario (estimación)
const ROUND_HOLDER_RISE_DEG := 40.0  # subida de la cara inferior de la cabeza con plaquita redonda (estimación)

## Forma de la plaquita (1.ª letra ISO 1832) y ángulo de punta εr
const SHAPES := {
	"C": { "name": "rómbica 80°", "eps_deg": 80.0, "source": SRC_ISO, "quality": "primary" },
	"D": { "name": "rómbica 55°", "eps_deg": 55.0, "source": SRC_ISO, "quality": "primary" },
	"V": { "name": "rómbica 35°", "eps_deg": 35.0, "source": SRC_ISO, "quality": "primary" },
	"T": { "name": "triangular 60°", "eps_deg": 60.0, "source": SRC_ISO, "quality": "primary" },
	"W": { "name": "trigonal 80°", "eps_deg": 80.0, "source": SRC_ISO, "quality": "primary" },
	"S": { "name": "cuadrada 90°", "eps_deg": 90.0, "source": SRC_ISO, "quality": "primary" },
	"R": { "name": "redonda", "eps_deg": 180.0, "source": SRC_ISO, "quality": "primary" },
	# plaquita de roscar de perfil completo (no es una forma de ISO 1832): V de 60° simétrica
	"M60": { "name": "perfil métrico 60° (roscar)", "eps_deg": 60.0, "source": SRC_THREAD, "quality": "primary" },
}

## Ángulo de incidencia normal de la plaquita (2.ª letra ISO 1832)
const CLEARANCE_DEG := { "N": 0.0, "B": 5.0, "C": 7.0, "P": 11.0 }

## Plaquitas. ic: círculo inscrito · l: longitud del filo · s: espesor · re: radio de punta (mm).
## ap y fn: [mínimo, recomendado, máximo] en mm y mm/rev, del catálogo (página en «page»). Los códigos de radio
## 02/04/08/12 son 0,2/0,4/0,8/1,2 mm (ISO 1832). Las rompevirutas -PF, -PM y -PR son de acabado, medio y desbaste.
const INSERTS := {
	"CCMT09T302-PF": { "shape": "C", "ic": 9.525, "l": 9.7, "s": 3.97, "re": 0.2, "clr": "C", "ap": [0.08, 0.35, 2.0], "fn": [0.04, 0.08, 0.15], "page": "A574" },
	"CNMG120404-PF": { "shape": "C", "ic": 12.7, "l": 12.9, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.25, 0.4, 1.5], "fn": [0.07, 0.15, 0.3], "page": "A567" },
	"CNMG120404-PM": { "shape": "C", "ic": 12.7, "l": 12.9, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.4, 3.0, 5.5], "fn": [0.1, 0.2, 0.3], "page": "A567" },
	"CNMG120408-PM": { "shape": "C", "ic": 12.7, "l": 12.9, "s": 4.76, "re": 0.8, "clr": "N", "ap": [0.5, 3.0, 5.5], "fn": [0.15, 0.3, 0.5], "page": "A567" },
	"CNMG120412-PR": { "shape": "C", "ic": 12.7, "l": 12.9, "s": 4.76, "re": 1.2, "clr": "N", "ap": [1.0, 4.0, 7.0], "fn": [0.25, 0.4, 0.7], "page": "A567" },
	"DCMT11T302-PF": { "shape": "D", "ic": 9.525, "l": 11.6, "s": 3.97, "re": 0.2, "clr": "C", "ap": [0.08, 0.35, 2.0], "fn": [0.04, 0.08, 0.15], "page": "A575" },
	"DNMG150404-PF": { "shape": "D", "ic": 12.7, "l": 15.5, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.25, 0.4, 1.5], "fn": [0.07, 0.15, 0.3], "page": "A569" },
	"DNMG150408-PM": { "shape": "D", "ic": 12.7, "l": 15.5, "s": 4.76, "re": 0.8, "clr": "N", "ap": [0.5, 3.0, 6.0], "fn": [0.15, 0.3, 0.5], "page": "A569" },
	"DNMG150412-PR": { "shape": "D", "ic": 12.7, "l": 15.5, "s": 4.76, "re": 1.2, "clr": "N", "ap": [1.0, 4.0, 6.0], "fn": [0.25, 0.4, 0.7], "page": "A569" },
	"VBMT160402-PF": { "shape": "V", "ic": 9.525, "l": 16.6, "s": 4.76, "re": 0.2, "clr": "B", "ap": [0.07, 0.32, 1.8], "fn": [0.04, 0.07, 0.14], "page": "A577" },
	"VNMG160404-PF": { "shape": "V", "ic": 9.525, "l": 16.6, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.25, 0.4, 1.5], "fn": [0.07, 0.15, 0.3], "page": "A573" },
	"VNMG160408-PM": { "shape": "V", "ic": 9.525, "l": 16.6, "s": 4.76, "re": 0.8, "clr": "N", "ap": [0.5, 2.0, 4.0], "fn": [0.15, 0.3, 0.5], "page": "A573" },
	"VNMG160412-PM": { "shape": "V", "ic": 9.525, "l": 16.6, "s": 4.76, "re": 1.2, "clr": "N", "ap": [0.8, 2.0, 4.0], "fn": [0.18, 0.35, 0.6], "page": "A573" },
	"TNMG160404-PF": { "shape": "T", "ic": 9.525, "l": 16.5, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.25, 0.4, 1.5], "fn": [0.07, 0.15, 0.3], "page": "A571" },
	"TNMG160408-PM": { "shape": "T", "ic": 9.525, "l": 16.5, "s": 4.76, "re": 0.8, "clr": "N", "ap": [0.5, 3.0, 5.0], "fn": [0.15, 0.3, 0.5], "page": "A571" },
	"TNMG160412-PR": { "shape": "T", "ic": 9.525, "l": 16.5, "s": 4.76, "re": 1.2, "clr": "N", "ap": [1.0, 3.0, 6.0], "fn": [0.25, 0.4, 0.65], "page": "A571" },
	"WNMG080404-PF": { "shape": "W", "ic": 12.7, "l": 8.7, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.25, 0.4, 1.5], "fn": [0.07, 0.15, 0.3], "page": "A572" },
	"WNMG080408-PM": { "shape": "W", "ic": 12.7, "l": 8.7, "s": 4.76, "re": 0.8, "clr": "N", "ap": [0.5, 2.5, 4.0], "fn": [0.15, 0.3, 0.5], "page": "A573" },
	"WNMG080412-PR": { "shape": "W", "ic": 12.7, "l": 8.7, "s": 4.76, "re": 1.2, "clr": "N", "ap": [1.0, 4.0, 5.0], "fn": [0.25, 0.4, 0.7], "page": "A573" },
	"SNMG120404-PM": { "shape": "S", "ic": 12.7, "l": 12.7, "s": 4.76, "re": 0.4, "clr": "N", "ap": [0.4, 3.0, 6.0], "fn": [0.1, 0.2, 0.3], "page": "A570" },
	"SNMG120408-PM": { "shape": "S", "ic": 12.7, "l": 12.7, "s": 4.76, "re": 0.8, "clr": "N", "ap": [0.5, 3.0, 6.0], "fn": [0.15, 0.3, 0.5], "page": "A570" },
	"SNMG120412-PR": { "shape": "S", "ic": 12.7, "l": 12.7, "s": 4.76, "re": 1.2, "clr": "N", "ap": [1.0, 4.0, 7.0], "fn": [0.25, 0.4, 0.7], "page": "A570" },
	"RNMG120400": { "shape": "R", "ic": 12.7, "l": 0.0, "s": 4.76, "re": 6.35, "clr": "N", "ap": [1.2, 3.0, 4.8], "fn": [0.073, 0.184, 0.368], "page": "A570" },
	# De roscar M…×2,5 (CoroThread 266). re: radio de fondo del perfil básico, H/6 (ISO 68-1), el que copia una
	# plaquita de perfil completo. l: largo del flanco que llega a la altura del perfil HA = 1,87 mm sobre la punta
	# (HA − rε·(1 − sen 30°) a lo largo de un flanco a 60° del eje, más el tramo que ocupa el redondeo). ap: la máxima es
	# HA (más honda, cortaría el cuerpo de la plaquita); la mínima y la recomendada, estimación. fn: el avance por
	# vuelta al roscar es el paso TP. ic y s: estimación (no están en la tabla del catálogo consultada).
	"266RG-16MM01A250M": { "shape": "M60", "ic": 9.525, "l": 2.576, "s": 3.97, "re": 0.361, "clr": "C", "ap": [0.05, 0.15, 1.87], "fn": [2.5, 2.5, 2.5], "page": "CoroThread 266", "thread": true, "pitch": 2.5 },
}

## Portaherramientas exteriores a derechas, mango 25 × 25. kr: ángulo de posición κr (KAPR). b, h: mango. lf: longitud
## funcional. wf: distancia de la punta a la cara trasera del mango. ohx: voladizo máximo. seat: asiento de plaquita
## negativa o positiva. En la redonda el ángulo de posición depende de ap (se calcula en el torno).
const HOLDERS := {
	"PCLNR2525M12": { "shape": "C", "kr": 95.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 27.0, "seat": "negativa", "page": "A148" },
	"SCLCR2525M09": { "shape": "C", "kr": 95.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 26.0, "seat": "positiva", "page": "A346" },
	"PDJNR2525M15": { "shape": "D", "kr": 93.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 36.0, "seat": "negativa", "page": "A153" },
	"SDJCR2525M11": { "shape": "D", "kr": 93.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 24.0, "seat": "positiva", "page": "A351" },
	"PVJNR2525M16HP": { "shape": "V", "kr": 93.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 45.0, "seat": "negativa", "page": "A177" },
	"SVJBR2525M16": { "shape": "V", "kr": 93.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 31.0, "seat": "positiva", "page": "A373" },
	"PTGNR2525M16": { "shape": "T", "kr": 91.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 22.0, "seat": "negativa", "page": "A172" },
	"PWLNR2525M08HP": { "shape": "W", "kr": 95.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 36.0, "seat": "negativa", "page": "A181" },
	"PSSNR2525M12": { "shape": "S", "kr": 45.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 29.0, "seat": "negativa", "page": "A164" },
	"PSBNR2525M12": { "shape": "S", "kr": 75.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 22.0, "ohx": 27.0, "seat": "negativa", "page": "A162" },
	"PRGNR2525M12": { "shape": "R", "kr": 90.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 27.0, "seat": "negativa", "page": "A155" },
	# roscar exterior a derechas: κr = 60° es el flanco de la V (ohx: largo de la cabeza, 22,2 mm)
	"266RFG-2525-16": { "shape": "M60", "kr": 60.0, "b": 25.0, "h": 25.0, "lf": 150.0, "wf": 32.0, "ohx": 22.2, "seat": "positiva", "page": "CoroThread 266" },
}

## Herramientas montadas del catálogo: [portaherramientas, plaquita]. Una por forma y radio de punta típico.
const TOOLS := [
	["SCLCR2525M09", "CCMT09T302-PF"],
	["PCLNR2525M12", "CNMG120404-PF"],
	["PCLNR2525M12", "CNMG120404-PM"],
	["PCLNR2525M12", "CNMG120408-PM"],
	["PCLNR2525M12", "CNMG120412-PR"],
	["SDJCR2525M11", "DCMT11T302-PF"],
	["PDJNR2525M15", "DNMG150404-PF"],
	["PDJNR2525M15", "DNMG150408-PM"],
	["PDJNR2525M15", "DNMG150412-PR"],
	["SVJBR2525M16", "VBMT160402-PF"],
	["PVJNR2525M16HP", "VNMG160404-PF"],
	["PVJNR2525M16HP", "VNMG160408-PM"],
	["PVJNR2525M16HP", "VNMG160412-PM"],
	["PTGNR2525M16", "TNMG160404-PF"],
	["PTGNR2525M16", "TNMG160408-PM"],
	["PTGNR2525M16", "TNMG160412-PR"],
	["PWLNR2525M08HP", "WNMG080404-PF"],
	["PWLNR2525M08HP", "WNMG080408-PM"],
	["PWLNR2525M08HP", "WNMG080412-PR"],
	["PSSNR2525M12", "SNMG120408-PM"],
	["PSBNR2525M12", "SNMG120404-PM"],
	["PSBNR2525M12", "SNMG120412-PR"],
	["PRGNR2525M12", "RNMG120400"],
	["266RFG-2525-16", "266RG-16MM01A250M"],
]

const ROUGH := "PCLNR2525M12/CNMG120408-PM"  # desbaste: rómbica 80° en portaherramientas de 95°
const FINISH := "PDJNR2525M15/DNMG150404-PF"  # acabado y copiado: rómbica 55° en portaherramientas de 93°
const THREAD := "266RFG-2525-16/266RG-16MM01A250M"  # roscar M…×2,5 exterior (CoroThread 266, 60°)
## Códigos de forma de la punta (Fagor 8055 T, p. 129-130): torneado exterior con la punta abajo a la izquierda, y roscar
## con la punta en el eje de la V
const LOCATION_TURN := 3
const LOCATION_THREAD := 62


static func ids() -> Array[String]:
	var out: Array[String] = []
	for pair in TOOLS:
		out.append("%s/%s" % [pair[0], pair[1]])
	return out


## La herramienta montada con ese id («PORTA/PLAQUITA»), o {} si no existe en el catálogo.
static func tool(id: String) -> Dictionary:
	var parts := id.split("/")
	if parts.size() != 2 or not HOLDERS.has(parts[0]) or not INSERTS.has(parts[1]):
		return {}
	return make_tool(parts[0], parts[1])


## Una herramienta de la forma y el radio de punta pedidos (la primera del catálogo), o {}.
static func find(shape: String, re_mm: float) -> Dictionary:
	for pair in TOOLS:
		var ins: Dictionary = INSERTS[pair[1]]
		if ins["shape"] == shape and absf(float(ins["re"]) - re_mm) < 1e-9:
			return make_tool(pair[0], pair[1])
	return {}


## Monta una plaquita en un portaherramientas y calcula los ángulos y polígonos derivados.
static func make_tool(holder_id: String, insert_id: String) -> Dictionary:
	var h: Dictionary = HOLDERS[holder_id]
	var ins: Dictionary = INSERTS[insert_id]
	var shape: String = ins["shape"]
	var eps: float = SHAPES[shape]["eps_deg"]
	var round_insert := shape == "R"
	var kr: float = h["kr"]
	var re: float = ins["re"]
	var clr: float = CLEARANCE_DEG[ins["clr"]]
	var negative: bool = h["seat"] == "negativa"
	var thread: bool = ins.get("thread", false)
	var t := {
		"id": "%s/%s" % [holder_id, insert_id],
		"holder": holder_id,
		"insert": insert_id,
		"tool_material": INSERT_TOOL_MATERIAL,  # id del catálogo de corte (tool_materials.gd)
		"shape": shape,
		"shape_name": SHAPES[shape]["name"],
		"eps_deg": eps,
		"kr_deg": kr,
		"re_mm": re,
		"ic_mm": ins["ic"],
		"l_mm": ins["l"],
		"s_mm": ins["s"],
		"clearance_deg": clr,  # incidencia normal de la plaquita (ISO 1832)
		"eff_clearance_deg": NEG_SEAT_CLEARANCE_DEG if negative else clr,  # en el asiento
		"seat": h["seat"],
		"ap_mm": ins["ap"].duplicate(),
		"fn_mm": ins["fn"].duplicate(),
		"ap_max_mm": ins["ap"][2],
		"holder_dims": { "b": h["b"], "h": h["h"], "lf": h["lf"], "wf": h["wf"], "ohx": h["ohx"] },
		"location": LOCATION_THREAD if thread else LOCATION_TURN,
		"center": [0.0, re] if thread else [re, re],  # centro de la punta respecto a la punta teórica (dz, dr)
		"source": "%s (portaherramientas, pág. %s) · %s (pág. %s) · %s" % [SRC_HOLDER, h["page"], SRC_CUT, ins["page"], SRC_ISO],
		"quality": "primary",
		"sources": {
			"geometry": SRC_ISO + " · " + SRC_HOLDER,
			"cutting_data": "%s, pág. %s" % [SRC_CUT, ins["page"]],
			"copy_angle": SRC_FREE,
			"holder_poly": "estimación a partir de B, H, LF y WF del catálogo (la forma de la cabeza no se publica)",
			"eff_clearance": SRC_SEAT + " (el valor de 6° es una estimación)",
		},
		"qualities": { "geometry": "primary", "cutting_data": "primary", "copy_angle": "secondary", "holder_poly": "estimate", "eff_clearance": "estimate" },
	}
	var geo := _corner_points(t, h)
	var kr_minor: float = geo["kr_minor_deg"]
	t["kr_minor_deg"] = kr_minor
	# Rampa máxima hacia el plato: el filo secundario (o la cabeza, con plaquita redonda) debe quedar al menos 2° por
	# encima de la superficie recién generada.
	t["copy_angle_max_deg"] = maxf(kr_minor - FREE_ANGLE_MIN_DEG, 0.0)
	t["copy_angle_rec_deg"] = maxf(kr_minor - FREE_ANGLE_REC_DEG, 0.0)
	t["holder_poly"] = geo["holder"]
	t["insert_poly"] = geo["insert"]
	t["name"] = "%s %s · %s, κr %s°, rε %s mm" % [insert_id, "(plaquita " + SHAPES[shape]["name"] + ")", holder_id, _deg_str(kr), _num_str(re)]
	if thread:
		t["pitch_mm"] = ins["pitch"]
		t["name"] = "%s (roscar, paso %s mm, 60°) · %s, rε %s mm" % [insert_id, _num_str(ins["pitch"]), holder_id, _num_str(re)]
		t["source"] = "%s · %s · %s · %s" % [SRC_THREAD, SRC_THREAD_HOLDER, SRC_ISO68, SRC_LOCATION]
		t["quality"] = "secondary"
		t["sources"] = {
			"geometry": SRC_THREAD + " · " + SRC_ISO68,
			"cutting_data": SRC_THREAD + " (TP: el avance por vuelta es el paso; ap máxima = HA)",
			"copy_angle": SRC_FREE,
			"holder_poly": "estimación a partir de B, H, LF y WF de " + SRC_THREAD_HOLDER,
			"eff_clearance": "estimación: incidencia de 7° de una plaquita de roscar rectificada",
			"location": SRC_LOCATION,
		}
		t["qualities"] = { "geometry": "secondary", "cutting_data": "estimate", "copy_angle": "secondary", "holder_poly": "estimate", "eff_clearance": "estimate", "location": "primary" }
	if round_insert:
		t["name"] = "%s (plaquita redonda Ø%s) · %s" % [insert_id, _num_str(ins["ic"]), holder_id]
		t["qualities"]["copy_angle"] = "estimate"
		t["sources"]["copy_angle"] = SRC_FREE + " aplicado a la cara inferior estimada de la cabeza"
	return t


## Ángulos y polígonos derivados, en coordenadas de herramienta (dz, dr) respecto a la punta teórica P.
## - Esquina afilada Q: intersección de los dos filos; el centro de la punta es P + center ((rε, rε), o (0, rε) en la
##   de roscar).
## - V_M y V_m: extremos del filo principal y del secundario (a la longitud l del filo desde Q).
## - Cabeza del portaherramientas: envolvente convexa de V_M, V_m y el mango (cara delantera a wf − b, trasera a wf).
static func _corner_points(t: Dictionary, h: Dictionary) -> Dictionary:
	var re: float = t["re_mm"]
	var kr: float = t["kr_deg"]
	var eps: float = t["eps_deg"]
	var wf: float = h["wf"]
	var b: float = h["b"]
	var lf: float = h["lf"]
	var cz: float = t["center"][0]
	var cr: float = t["center"][1]
	var vmin_z: float
	var vmin_r: float
	var vmaj_z: float
	var vmaj_r: float
	var kr_minor: float
	var insert := PackedFloat64Array()
	if t["shape"] == "R":
		# plaquita redonda: el círculo es todo filo; la cabeza la abraza por arriba a la derecha
		vmaj_z = cz + re * cos(deg_to_rad(120.0))
		vmaj_r = cr + re * sin(deg_to_rad(120.0))
		vmin_z = cz + re * cos(deg_to_rad(-30.0))
		vmin_r = cr + re * sin(deg_to_rad(-30.0))
		kr_minor = ROUND_HOLDER_RISE_DEG
	else:
		kr_minor = 180.0 - kr - eps
		var th_maj := deg_to_rad(180.0 - kr)  # dirección del filo principal desde la esquina
		var th_min := deg_to_rad(kr_minor)  # dirección del filo secundario
		# bisectriz hacia dentro de la plaquita y esquina afilada Q = C − rε/sin(ε/2)·bisectriz
		var bz := cos(th_maj) + cos(th_min)
		var br := sin(th_maj) + sin(th_min)
		var bl := sqrt(bz * bz + br * br)
		var q := re / sin(deg_to_rad(eps) / 2.0)
		var qz := cz - q * bz / bl
		var qr := cr - q * br / bl
		var l: float = t["l_mm"]
		vmaj_z = qz + l * cos(th_maj)
		vmaj_r = qr + l * sin(th_maj)
		vmin_z = qz + l * cos(th_min)
		vmin_r = qr + l * sin(th_min)
		# puntos de tangencia de los filos con el círculo de la punta (normales exteriores de cada filo)
		var n_maj := th_maj + PI / 2.0
		var n_min := th_min - PI / 2.0
		insert = PackedFloat64Array([cz + re * cos(n_maj), cr + re * sin(n_maj), vmaj_z, vmaj_r, vmin_z, vmin_r, cz + re * cos(n_min), cr + re * sin(n_min)])
	var rise := deg_to_rad(minf(kr_minor + HOLDER_BOTTOM_EXTRA_DEG, 75.0))
	if t["shape"] == "R":
		rise = deg_to_rad(ROUND_HOLDER_RISE_DEG)
	var back_r := vmin_r + maxf(wf - vmin_z, 0.0) * tan(rise)
	var pts := PackedFloat64Array([vmaj_z, vmaj_r, vmin_z, vmin_r, wf - b, maxf(HEAD_H_MM, vmaj_r), wf - b, lf, wf, lf, wf, maxf(back_r, vmin_r)])
	return { "kr_minor_deg": kr_minor, "holder": convex_hull(pts), "insert": convex_hull(insert) if insert.size() > 0 else insert }


## Envolvente convexa (cadena monótona de Andrew) de puntos (z, r) en un PackedFloat64Array plano. Devuelve los
## vértices en sentido antihorario, empezando por el de menor z.
static func convex_hull(flat: PackedFloat64Array) -> PackedFloat64Array:
	var n := flat.size() / 2
	var idx: Array[int] = []
	for i in n:
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool: return flat[2 * a] < flat[2 * b] or (flat[2 * a] == flat[2 * b] and flat[2 * a + 1] < flat[2 * b + 1]))
	if n < 3:
		var out := PackedFloat64Array()
		for i in idx:
			out.append(flat[2 * i])
			out.append(flat[2 * i + 1])
		return out
	var hull: Array[int] = []
	for pass_i in 2:
		var start := hull.size()
		var order := idx if pass_i == 0 else _reversed(idx)
		for i in order:
			while hull.size() >= start + 2 and _cross(flat, hull[hull.size() - 2], hull[hull.size() - 1], i) <= 0.0:
				hull.pop_back()
			hull.append(i)
		hull.pop_back()
	var out := PackedFloat64Array()
	for i in hull:
		out.append(flat[2 * i])
		out.append(flat[2 * i + 1])
	return out


static func _reversed(a: Array[int]) -> Array[int]:
	var out: Array[int] = a.duplicate()
	out.reverse()
	return out


static func _cross(f: PackedFloat64Array, o: int, a: int, b: int) -> float:
	return (f[2 * a] - f[2 * o]) * (f[2 * b + 1] - f[2 * o + 1]) - (f[2 * a + 1] - f[2 * o + 1]) * (f[2 * b] - f[2 * o])


## Geometría de corte relativa al CENTRO de la punta, lista para estampar: la envolvente inferior e(u) (r − r_centro)
## en función de u = z − z_centro. Tramos: filo principal (solo si κr < 90°, sube hacia el plato), arco de la punta y
## filo secundario (sube hacia el contrapunto), cada filo hasta su longitud útil.
static func cut_geometry(t: Dictionary) -> Dictionary:
	var re: float = t["re_mm"]
	var g := { "re": re, "re2": re * re, "round": t["shape"] == "R" }
	if t["shape"] == "R":
		g.merge({ "u_lo": -re, "u_hi": re, "uM": -re - 1.0, "eM": 0.0, "tM": 0.0, "um": re + 1.0, "em": 0.0, "tm": 0.0 })
		return g
	var kr: float = t["kr_deg"]
	var krm: float = t["kr_minor_deg"]
	var eps: float = t["eps_deg"]
	# longitud recta útil de cada filo: la del filo menos lo que ocupa el redondeo de la punta (rε/tan(ε/2))
	var straight := maxf(float(t["l_mm"]) - re / tan(deg_to_rad(eps) / 2.0), 0.0)
	if kr < 90.0:
		var a := deg_to_rad(kr)
		g["uM"] = -re * sin(a)
		g["eM"] = -re * cos(a)
		g["tM"] = tan(a)
		g["u_lo"] = g["uM"] - straight * cos(a)
	else:
		g["uM"] = -re - 1.0  # sin tramo de filo principal en la envolvente inferior
		g["eM"] = 0.0
		g["tM"] = 0.0
		g["u_lo"] = -re
	if krm < 90.0:
		var am := deg_to_rad(krm)
		g["um"] = re * sin(am)
		g["em"] = -re * cos(am)
		g["tm"] = tan(am)
		g["u_hi"] = g["um"] + straight * cos(am)
	else:
		g["um"] = re + 1.0
		g["em"] = 0.0
		g["tm"] = 0.0
		g["u_hi"] = re
	return g


## Envolvente inferior de corte en u (relativa al centro de la punta); INF fuera de la herramienta.
static func env(g: Dictionary, u: float) -> float:
	if u < g["u_lo"] or u > g["u_hi"]:
		return INF
	if u < g["uM"]:
		return g["eM"] + (g["uM"] - u) * g["tM"]
	if u <= g["um"]:
		return -sqrt(maxf(g["re2"] - u * u, 0.0))
	return g["em"] + (u - g["um"]) * g["tm"]


## Ángulo de posición efectivo (grados) con profundidad ap: en la redonda y cuando solo corta el arco de la punta es el
## del arco a esa profundidad, acos(1 − ap/rε) (la fórmula de Sandvik para plaquitas redondas); si no, κr.
static func kr_eff_deg(t: Dictionary, ap: float) -> float:
	var re: float = t["re_mm"]
	if ap <= 0.0:
		return 0.0
	if t["shape"] == "R":
		return rad_to_deg(acos(clampf(1.0 - ap / re, -1.0, 1.0)))
	var kr: float = t["kr_deg"]
	if ap < re * (1.0 - cos(deg_to_rad(kr))):
		return rad_to_deg(acos(clampf(1.0 - ap / re, -1.0, 1.0)))
	return kr


## Número corto con coma decimal (String(n) de JavaScript, como en el laboratorio).
static func _num_str(x: float) -> String:
	return Js.js_num_str(x).replace(".", ",")


static func _deg_str(x: float) -> String:
	return _num_str(x)
