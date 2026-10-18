## Chispas de la radial (y de la afiladora): de la salida del modelo de corte a partículas para un MultiMesh.
##
## Qué es una chispa: una partícula de acero arrancada al rojo que sigue ardiendo en el aire. Sale tangente al
## disco donde el borde abandona el material, con una velocidad del orden de la periférica; frena por la
## resistencia del aire (arrastre cuadrático: recorre L·ln(1 + v0·t/L)) y se apaga. En los aceros con carbono, el
## Fe₃C que se oxida dentro de la gota forma bolsas de gas que la hacen estallar en pleno vuelo: los «estallidos»
## (Guillen et al. 2019). Colores, longitudes y estallidos de cada material: ensayo de chispas, TC 9-237 (1993),
## tabla 7-5; color de cada chispa: el de incandescencia de su temperatura, TM 9-237 (1967), tabla V.
## El aluminio, el cobre, el latón y los plásticos no dan haz de chispas (tabla 7-5, fila 15).
##
## Una sola fuente (fase 2): el volumen, la longitud, el color y los estallidos del haz de cada material salen de aquí
## (stream_for, tabla 7-5 del TC 9-237); radial.gd los copia en la salida de cut_panel y solo pone cuántas chispas por
## segundo salen según el caudal. Así el haz que da el modelo y el que dibuja el emisor son el mismo.
##
## Contrato con el modelo de corte (core/taller/radial.gd → cut_panel): de su salida se usan `vs_ms` y
## `sparks: { rate, color, length_mm, bursts }`:
## - rate: chispas visibles por segundo que salen del corte (valor para dibujar, no el número real de virutas);
## - length_mm: longitud del haz en las condiciones del corte (ya incluye el efecto de vs);
## - bursts: estallidos por chispa (media; >1 = estallidos repetidos);
## - color: color del haz junto al disco («#RRGGBB» o Color).
## Lo que falte se completa con la firma del material (fallback físico, marcado en `resolve_stream`).
##
## Uso:
##   const Sparks = preload("res://core/taller/sparks.gd")
##   var em := Sparks.new("radial:caso-1")
##   em.configure("acero-dulce", result["sparks"], result["vs_ms"])
##   em.set_pose({ "center": c, "axis": a, "radius": r, "contact": p, "normal": n, "spin": 1.0, "kerf": 0.001 })
##   em.step(delta)
##   multimesh.buffer = em.buffer(1.0 / 60.0, 0.0005)   # 20 floats por chispa: transformación 3D + color + custom
## Todo en metros y segundos (es geometría de escena). Determinista: el azar sale de core/shared/rng.gd.
extends RefCounted

const Rng = preload("res://core/shared/rng.gd")

## Chispas vivas como máximo (carriers + ramas). Con 2000 chispas/s y vidas de ~0,1 s hay ~200 a la vez.
const MAX_SPARKS := 1600
## Floats por chispa en el búfer del MultiMesh: 12 de la transformación, 4 de color y 4 de datos propios.
const FLOATS_PER_SPARK := 20
## Longitud de frenado L = (4/3)·(ρp/ρaire)·d/Cd para una gota de ~100 µm (ρp ≈ 7000 kg/m³, Cd ≈ 1).
## ESTIMACIÓN: no hay medición publicada del tamaño medio de las chispas de un disco de corte.
const DRAG_LENGTH_M := 0.8
## Fracción de la velocidad periférica con la que sale la chispa. ESTIMACIÓN (la viruta sale casi a vs).
const EJECT_MIN := 0.55
const EJECT_MAX := 1.0
## Abanico: en el plano del disco la chispa se abre poco; fuera del plano, menos aún (el haz de un disco de corte
## es una lámina fina). ESTIMACIÓN a partir de fotografías de cortes.
const SPREAD_IN_PLANE_DEG := 9.0
const SPREAD_OUT_PLANE_DEG := 2.5
## Velocidad de referencia del ensayo de chispas: TC 9-237 pide al menos 1525 m/min (25 m/s); una muela de banco
## de 12 in a 1750-3450 rpm va a 28-55 m/s. Se usa 35 m/s para escalar las longitudes de la tabla 7-5.
const VS_REF_MS := 35.0
## Chispas visibles por segundo de un haz de volumen 1 («Large» en la tabla 7-5) a VS_REF_MS. ESTIMACIÓN visual.
const RATE_REF := 1000.0
const GRAVITY := Vector3(0.0, -9.81, 0.0)
## Último tramo de la vida en el que la chispa se enfría y se apaga. ESTIMACIÓN visual.
const COOL_FRACTION := 0.15
## Temperatura a la que la chispa deja de verse (rojo tenue, visible en la oscuridad: 750 °F, tabla V).
const T_DARK_C := 399.0
## Exposición por defecto de la «cámara» (s): cada chispa se guarda este tiempo después de apagarse para que su
## estela se siga dibujando, como en una foto (lo que se apagó durante la exposición también sale).
const EXPOSURE_S := 1.0 / 60.0

## Colores de calor del acero, TM 9-237 (1967), apéndice, tabla V «Heat colors with approximate temperature».
## Temperaturas pasadas de °F a °C; el RGB de cada nombre es una ESTIMACIÓN para pantalla.
const HEAT_COLORS := [
	[399.0, Color(0.30, 0.03, 0.02)],  # rojo tenue, visible en la oscuridad (750 °F)
	[482.0, Color(0.45, 0.05, 0.03)],  # rojo tenue (900 °F)
	[566.0, Color(0.58, 0.06, 0.04)],  # rojo sangre (1050 °F)
	[635.0, Color(0.68, 0.09, 0.05)],  # cereza oscuro (1175 °F)
	[677.0, Color(0.75, 0.12, 0.06)],  # cereza medio (1250 °F)
	[746.0, Color(0.84, 0.16, 0.07)],  # cereza o rojo pleno (1375 °F)
	[788.0, Color(0.90, 0.22, 0.08)],  # cereza brillante o rojo apagado (1450 °F)
	[843.0, Color(0.96, 0.30, 0.09)],  # rojo brillante (1550 °F)
	[899.0, Color(1.00, 0.45, 0.20)],  # salmón (1650 °F)
	[941.0, Color(1.00, 0.56, 0.12)],  # naranja (1725 °F)
	[996.0, Color(1.00, 0.84, 0.30)],  # limón (1825 °F)
	[1079.0, Color(1.00, 0.93, 0.55)],  # amarillo claro (1975 °F)
	[1204.0, Color(1.00, 0.98, 0.88)],  # blanco (2200 °F)
]

## Palabras de color del ensayo de chispas (tabla 7-5) → temperatura por la tabla V. La asignación es una
## ESTIMACIÓN: «paja» se toma como el limón de la tabla V y «amarillo-naranja» (texto del TC 9-237 para el acero
## de bajo carbono) entre el naranja y el limón.
const COLOR_WORD_TEMP_C := {
	"rojo": 788.0,
	"naranja": 941.0,
	"naranja-claro": 970.0,
	"amarillo-naranja": 970.0,
	"paja": 996.0,
	"blanco": 1204.0,
}
## Las mismas palabras, como se escriben en la interfaz.
const COLOR_WORD_NAME := {
	"rojo": "rojo",
	"naranja": "naranja",
	"naranja-claro": "naranja claro",
	"amarillo-naranja": "amarillo anaranjado",
	"paja": "paja",
	"blanco": "blanco",
}
## Estallidos por chispa → palabra de la tabla 7-5 (la escala de FAMILIES) y forma del estallido.
const BURST_WORDS := [
	[0.0, "ninguna"], [0.03, "extremadamente pocas"], [0.08, "muy pocas"], [0.15, "pocas"], [0.35, "moderadas"],
	[0.7, "muchas"], [1.2, "muchísimas"],
]
const BURST_KIND_NAME := { "forked": "en horquilla", "repeating": "repetidas, en estrella" }
## Cita corta del ensayo de chispas (la lista `sources` de cut_panel)
const CITE := "TC 9-237 (1993), tabla 7-5 (ensayo de chispas)"

## Firmas del ensayo de chispas. `volume` y `bursts` traducen a números las palabras de la tabla 7-5
## (Large 1 · Moderately large 0,8 · Moderate 0,6 · Small 0,4 · Very small 0,2 · None 0; estallidos por chispa:
## Extremely few 0,03 · Very few 0,08 · Few 0,15 · Moderate 0,35 · Many 0,7 · Very many 1,2): ESTIMACIÓN.
## `length_mm`: longitud relativa del haz de la tabla (muela de 12 in en banco). `burst_kind`: «forked» (la línea se
## divide en tres al final, en horquilla) o «repeating» (estrellas finas y repetidas a lo largo del haz).
const FAMILIES := {
	"hierro": {
		"name": "hierro casi puro",
		"volume": 1.0, "length_mm": 1651.0, "col_wheel": "paja", "col_end": "blanco",
		"bursts": 0.08, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 1 (wrought iron)",
	},
	"acero_bajo_c": {
		"name": "acero de bajo carbono",
		"volume": 1.0, "length_mm": 1778.0, "col_wheel": "amarillo-naranja", "col_end": "blanco",
		"bursts": 0.15, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 2 (AISI 1020), y §7-3: estelas largas amarillo-naranja"
			+ " que tienden a estallar en horquillas blancas",
	},
	"acero_mn": {
		"name": "acero de fase dual con manganeso",
		"volume": 1.0, "length_mm": 1700.0, "col_wheel": "amarillo-naranja", "col_end": "blanco",
		"bursts": 0.35, "burst_kind": "forked", "quality": "estimate",
		"source": "TC 9-237 (1993) §7-3: el Mn aumenta el volumen del haz y la fuerza de los estallidos; con Mn"
			+ " por encima de lo normal chispea como un acero de más carbono. Números: estimación entre las filas 2"
			+ " y 3 de la tabla 7-5",
	},
	"acero_mn_b": {
		"name": "acero al boro templado en prensa (22MnB5)",
		"volume": 1.0, "length_mm": 1600.0, "col_wheel": "paja", "col_end": "blanco",
		"bursts": 0.7, "burst_kind": "repeating", "quality": "estimate",
		"source": "TC 9-237 (1993) §7-3 (efecto del Mn) y tabla 7-5, filas 2 y 3; 22MnB5: C 0,22 %,"
			+ " Mn 1,1-1,4 % (EN 10083-3). Números: estimación",
	},
	"acero_alto_c": {
		"name": "acero de herramientas al carbono",
		"volume": 0.8, "length_mm": 1397.0, "col_wheel": "blanco", "col_end": "blanco",
		"bursts": 1.2, "burst_kind": "repeating", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 3 (carbon tool steel)",
	},
	"inox": {
		"name": "acero inoxidable austenítico (18-8)",
		"volume": 0.6, "length_mm": 825.0, "col_wheel": "naranja", "col_end": "paja",
		"bursts": 0.35, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993) §7-3: el 18-8 chispea como el hierro pero con la mitad de longitud,"
			+ " estallidos en horquilla moderados; color naranja a paja de la serie 300: Davis (ASM, Stainless"
			+ " Steels, 1994, pp. 126-127)",
	},
	"inox_martensitico": {
		"name": "acero inoxidable martensítico",
		"volume": 0.6, "length_mm": 1270.0, "col_wheel": "paja", "col_end": "blanco",
		"bursts": 0.35, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 9 (tipo 410)",
	},
	"hss": {
		"name": "acero rápido",
		"volume": 0.4, "length_mm": 1524.0, "col_wheel": "rojo", "col_end": "paja",
		"bursts": 0.03, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 7 (18-4-1)",
	},
	"fundicion": {
		"name": "fundición gris",
		"volume": 0.4, "length_mm": 635.0, "col_wheel": "rojo", "col_end": "paja",
		"bursts": 0.7, "burst_kind": "repeating", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 4 (gray cast iron)",
	},
	"niquel": {
		"name": "níquel",
		"volume": 0.2, "length_mm": 254.0, "col_wheel": "naranja", "col_end": "naranja",
		"bursts": 0.0, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 14 (nickel)",
	},
	"sin_chispas": {
		"name": "sin haz de chispas",
		"volume": 0.0, "length_mm": 0.0, "col_wheel": "rojo", "col_end": "rojo",
		"bursts": 0.0, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 15 (cobre, latón, aluminio: none) y §7-3 (los no férreos"
			+ " no dan haz); los plásticos se funden",
	},
	# Unidad 5l (cetrería: las garras reforjadas de titanio y de metal duro). Solo añadidos: las firmas de antes no cambian.
	"metal_duro": {
		"name": "metal duro (carburo de tungsteno con cobalto)",
		"volume": 0.1, "length_mm": 51.0, "col_wheel": "naranja-claro", "col_end": "naranja-claro",
		"bursts": 0.0, "burst_kind": "forked", "quality": "secondary",
		"source": "TC 9-237 (1993), tabla 7-5, fila 13 (cemented tungsten carbide: volumen «extremely small», 2 in, naranja"
			+ " claro junto a la muela y al final, sin estallidos; la misma fila en la «Spark Testing Identification Table»"
			+ " de Steel Elements); «extremely small» = 0,1 por debajo del «very small» = 0,2 de la escala: ESTIMACIÓN."
			+ " Kelley y Blickensderfer (1974), U.S. Bureau of Mines RI 7902, tabla 10: el carburo de tungsteno con cobalto,"
			+ " 30 µW/sr·cm² de radiancia del haz frente a los 787 del hierro casi puro (tabla 1)",
	},
	"titanio_cp": {
		"name": "titanio comercialmente puro",
		"volume": 1.0, "length_mm": 1651.0, "col_wheel": "blanco", "col_end": "blanco",
		"bursts": 0.0, "burst_kind": "forked", "quality": "estimate",
		"source": "Kelley y Blickensderfer (1974), U.S. Bureau of Mines RI 7902, tabla 1: el titanio da 743 µW/sr·cm² de"
			+ " radiancia del haz, como el hierro casi puro (787), y «the temperature of sparks from the reactive metals such"
			+ " as Ti, Cb, and Zr was much higher than the temperature of the steel sparks»: haz blanco. No está en la tabla"
			+ " 7-5 del TC 9-237: el volumen y la longitud, los del hierro de radiancia parecida (fila 1), y sin estallidos"
			+ " medidos: ESTIMACIÓN",
	},
}

## Material → familia del ensayo de chispas. Las chapas de la radial usan las claves de core/taller/panels.gd; el
## resto, los tipos de material de pieza de CONTRATOS.md y los aceros de afilado (claves de unión).
const MATERIAL_FAMILY := {
	"acero-dulce": "acero_bajo_c",
	"acero-bh": "acero_bajo_c",
	"dp800": "acero_mn",
	"boro-22mnb5": "acero_mn_b",
	"aluminio": "sin_chispas",
	"plastico-carroceria": "sin_chispas",
	"perfil-aluminio": "sin_chispas",
	"acero": "acero_bajo_c",
	"inox": "inox",
	"fundicion": "fundicion",
	"niquel": "niquel",
	"laton": "sin_chispas",
	"cobre": "sin_chispas",
	"titanio": "",
	"madera": "sin_chispas",
	"plastico": "sin_chispas",
	"piedra": "sin_chispas",
	"vidrio": "sin_chispas",
	"vg10": "inox_martensitico",
	"x50crmov15": "inox_martensitico",
	"14c28n": "inox_martensitico",
	"m2": "hss",
	"1095": "acero_alto_c",
	# Unidad 5l: las garras reforjadas de la cetrería (CareData.SPARK_MATERIAL). «titanio» (arriba) sigue sin firma para el
	# taller; la del titanio comercialmente puro de las garras es «titanio-cp». El oro, como el cobre: sin medición del oro, el
	# metal noble más parecido no da chispas (tabla 7-5, fila 15; RI 7902, tabla 1: el cobre, 0).
	"titanio-cp": "titanio_cp",
	"metal-duro": "metal_duro",
	"oro": "sin_chispas",
}

var _rng: Rng

# Haz configurado
var _family := "sin_chispas"
var _rate := 0.0
var _length_m := 0.0
var _bursts := 0.0
var _burst_kind := "forked"
var _t_wheel := 996.0
var _t_end := 1204.0
var _birth_color := Color(1.0, 0.84, 0.3)
var _vs := 0.0
var _life_mean := 0.0
var _suppressed := false

# Pose del disco (metros)
var _center := Vector3.ZERO
var _axis := Vector3(0.0, 0.0, 1.0)
var _radius := 0.0625
var _contact := Vector3(0.0, -0.0625, 0.0)
var _normal := Vector3.UP
var _spin := 1.0
var _kerf := 0.001
var _keep := EXPOSURE_S

# Contadores (para los tests y la interfaz)
var _acc := 0.0
var _emitted := 0
var _burst_count := 0
var _max_travel := 0.0
var _travel_sum := 0.0
var _dead := 0

# Partículas en arrays paralelos (una entrada por chispa viva)
var _p0 := PackedVector3Array()
var _dir := PackedVector3Array()
var _v0 := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _temp0 := PackedFloat32Array()
var _temp1 := PackedFloat32Array()
var _next_burst := PackedFloat32Array()
var _bursts_left := PackedInt32Array()
var _gen := PackedInt32Array()
var _buf := PackedFloat32Array()


func _init(seed_text: String = "chispas") -> void:
	_rng = Rng.new(Rng.seed_of(seed_text))


# ───────────────────────────── datos ─────────────────────────────


## Familia del ensayo de chispas de un material («» si no se conoce: no se inventan chispas).
static func family_of(material_id: String) -> String:
	return str(MATERIAL_FAMILY.get(material_id, ""))


## Firma del ensayo de chispas del material (la de «sin_chispas» si no se conoce).
static func signature_for(material_id: String) -> Dictionary:
	var fid := family_of(material_id)
	return FAMILIES[fid] if FAMILIES.has(fid) else FAMILIES["sin_chispas"]


## Color de incandescencia del acero a temperatura t (°C), interpolado en la tabla V del TM 9-237. Por debajo del
## rojo tenue se oscurece hasta negro (a 300 °C ya no se ve).
static func heat_color(temp_c: float) -> Color:
	var first: Array = HEAT_COLORS[0]
	if temp_c <= float(first[0]):
		var k := clampf((temp_c - 300.0) / (float(first[0]) - 300.0), 0.0, 1.0)
		return Color(0, 0, 0).lerp(first[1], k)
	for i in range(1, HEAT_COLORS.size()):
		var hi: Array = HEAT_COLORS[i]
		if temp_c <= float(hi[0]):
			var lo: Array = HEAT_COLORS[i - 1]
			var k := (temp_c - float(lo[0])) / (float(hi[0]) - float(lo[0]))
			return (lo[1] as Color).lerp(hi[1], k)
	return HEAT_COLORS[HEAT_COLORS.size() - 1][1]


## Temperatura (°C) de una palabra de color del ensayo de chispas.
static func word_temp_c(word: String) -> float:
	return float(COLOR_WORD_TEMP_C.get(word, 996.0))


## Tiempo (s) que tarda una partícula que sale a v0 con longitud de frenado L en recorrer s metros.
static func time_to_travel(s: float, v0: float, drag: float) -> float:
	if v0 <= 0.0:
		return 0.0
	return drag / v0 * (exp(s / drag) - 1.0)


## Distancia (m) recorrida en t segundos con arrastre cuadrático: L·ln(1 + v0·t/L).
static func travel(t: float, v0: float, drag: float) -> float:
	return drag * log(1.0 + v0 * maxf(t, 0.0) / drag)


## Longitud del haz (mm) a una velocidad del borde vs (m/s) a partir de la longitud de la tabla 7-5 (medida con la muela
## a VS_REF_MS): la chispa arde el mismo tiempo; si sale más rápida, llega más lejos (arrastre cuadrático).
static func stream_length_mm(table_length_mm: float, vs_ms: float) -> float:
	if table_length_mm <= 0.0 or vs_ms <= 0.0:
		return 0.0
	var t_ref := time_to_travel(table_length_mm / 1000.0, VS_REF_MS, DRAG_LENGTH_M)
	return travel(t_ref, vs_ms, DRAG_LENGTH_M) * 1000.0


## El haz de chispas de un material con el borde del disco a vs (m/s): la única fuente de volumen, longitud, color y
## estallidos del taller (TC 9-237, tabla 7-5). La usan radial.gd (salida de cut_panel) y resolve_stream().
## → { family, known, volume (tamaño del haz, 0-1), length_mm, color y color_end («#RRGGBB» junto a la muela y al final;
##     "" si no chispea), color_name, color_end_name, bursts (por chispa), bursts_name, burst_kind, quality, source,
##     cite }. Un material sin firma no se inventa chispas (family "sin_chispas", known false).
static func stream_for(material_id: String, vs_ms: float) -> Dictionary:
	var fid := family_of(material_id)
	var fam := signature_for(material_id)
	var volume := float(fam["volume"])
	var sparkles := volume > 0.0
	var bursts := float(fam["bursts"]) if sparkles else 0.0
	return {
		"family": fid if fid != "" else "sin_chispas",
		"known": fid != "",
		"volume": volume,
		"length_mm": stream_length_mm(float(fam["length_mm"]), vs_ms) if sparkles else 0.0,
		"color": _hex(heat_color(word_temp_c(str(fam["col_wheel"])))) if sparkles else "",
		"color_name": str(COLOR_WORD_NAME.get(str(fam["col_wheel"]), "")) if sparkles else "",
		"color_end": _hex(heat_color(word_temp_c(str(fam["col_end"])))) if sparkles else "",
		"color_end_name": str(COLOR_WORD_NAME.get(str(fam["col_end"]), "")) if sparkles else "",
		"bursts": bursts,
		"bursts_name": burst_name(bursts, str(fam["burst_kind"])),
		"burst_kind": str(fam["burst_kind"]),
		"quality": str(fam["quality"]),
		"source": str(fam["source"]),
		"cite": CITE,
	}


## Estallidos por chispa en palabras de la tabla 7-5: la palabra más próxima de BURST_WORDS y su forma
## («muy pocas, en horquilla»); «ninguna» sin estallidos.
static func burst_name(bursts: float, burst_kind: String) -> String:
	if bursts <= 0.0:
		return "ninguna"
	var best: Array = BURST_WORDS[1]
	for row in BURST_WORDS:
		if float(row[0]) > 0.0 and absf(float(row[0]) - bursts) < absf(float(best[0]) - bursts):
			best = row
	return "%s, %s" % [str(best[1]), str(BURST_KIND_NAME.get(burst_kind, burst_kind))]


## «#RRGGBB» de un color de pantalla.
static func _hex(c: Color) -> String:
	return "#" + c.to_html(false).to_upper()


## El haz que se dibujará con esta salida del modelo: lo que da el modelo y, si falta algo, la firma del material.
## Si el material no da chispas en el ensayo (aluminio, plástico…), rate = 0 aunque el modelo diga otra cosa, y
## `suppressed` avisa de la discrepancia.
static func resolve_stream(material_id: String, sparks: Dictionary, vs_ms: float) -> Dictionary:
	var fid := family_of(material_id)
	var fam := signature_for(material_id)
	var vs := maxf(vs_ms, 0.0)
	var volume := float(fam["volume"])
	var model_rate := float(sparks.get("rate", -1.0)) if sparks.get("rate") != null else -1.0
	var model_len := float(sparks.get("length_mm", -1.0)) if sparks.get("length_mm") != null else -1.0
	var rate := 0.0
	var length_mm := 0.0
	if volume > 0.0 and vs > 0.0:
		# Longitud: la que da el modelo (que ya sale de stream_for) o, si falta, la misma cuenta (stream_length_mm)
		length_mm = model_len if model_len >= 0.0 else stream_length_mm(float(fam["length_mm"]), vs)
		rate = model_rate if model_rate >= 0.0 else volume * RATE_REF * vs / VS_REF_MS
	var bursts := float(fam["bursts"])
	if sparks.get("bursts") != null:
		bursts = maxf(float(sparks["bursts"]), 0.0)
	var t_wheel := word_temp_c(str(fam["col_wheel"]))
	var t_end := word_temp_c(str(fam["col_end"]))
	var color := heat_color(t_wheel)
	var model_color: Variant = sparks.get("color")
	if model_color is Color:
		color = model_color
	elif model_color is String and Color.html_is_valid(model_color):
		color = Color.html(model_color)
	var v_mean := vs * 0.5 * (EJECT_MIN + EJECT_MAX)
	var life := 0.0
	if rate > 0.0 and length_mm > 0.0:
		life = minf(time_to_travel(length_mm / 1000.0, v_mean, DRAG_LENGTH_M), 1.5)
	return {
		"family": fid if fid != "" else "sin_chispas",
		"known": fid != "",
		"rate": rate if life > 0.0 else 0.0,
		"length_mm": length_mm,
		"bursts": bursts,
		"burst_kind": str(fam["burst_kind"]),
		"t_wheel_c": t_wheel,
		"t_end_c": t_end,
		"color": color,
		"life_s": life,
		"suppressed": volume <= 0.0 and model_rate > 0.0,
		"from_model": {"rate": model_rate >= 0.0, "length": model_len >= 0.0, "color": model_color != null},
		"quality": str(fam["quality"]),
		"source": str(fam["source"]),
	}


# ───────────────────────────── emisor ─────────────────────────────


## Configura el haz con la salida del modelo (se puede llamar a cada cambio de rpm: las chispas vivas siguen).
func configure(material_id: String, sparks: Dictionary, vs_ms: float) -> void:
	var s := resolve_stream(material_id, sparks, vs_ms)
	_family = str(s["family"])
	_rate = float(s["rate"])
	_length_m = float(s["length_mm"]) / 1000.0
	_bursts = float(s["bursts"])
	_burst_kind = str(s["burst_kind"])
	_t_wheel = float(s["t_wheel_c"])
	_t_end = float(s["t_end_c"])
	_birth_color = s["color"]
	_life_mean = float(s["life_s"])
	_suppressed = bool(s["suppressed"])
	_vs = maxf(vs_ms, 0.0)


## Pose del disco en metros: center, axis (eje de giro, unitario), radius, contact (punto donde el borde sale del
## material), normal (normal de la chapa en el contacto: las chispas no la atraviesan), spin (+1/−1: sentido de
## giro alrededor de axis) y kerf (anchura del surco: dispersión del punto de salida a lo largo del eje).
func set_pose(pose: Dictionary) -> void:
	_center = pose.get("center", _center)
	var ax: Vector3 = pose.get("axis", _axis)
	_axis = ax.normalized() if ax.length_squared() > 0.0 else _axis
	_radius = float(pose.get("radius", _radius))
	_contact = pose.get("contact", _center + Vector3.DOWN * _radius)
	var n: Vector3 = pose.get("normal", _normal)
	_normal = n.normalized() if n.length_squared() > 0.0 else _normal
	_spin = 1.0 if float(pose.get("spin", _spin)) >= 0.0 else -1.0
	_kerf = maxf(float(pose.get("kerf", _kerf)), 0.0)


## Exposición de la cámara (s) con la que se van a dibujar las estelas: cuánto se guarda cada chispa apagada.
func set_exposure(seconds: float) -> void:
	_keep = maxf(seconds, 0.0)


## Borra las chispas vivas y los contadores (la configuración y la pose se quedan).
func reset() -> void:
	for arr in [_p0, _dir, _v0, _drag, _age, _life, _temp0, _temp1, _next_burst, _bursts_left, _gen]:
		arr.resize(0)
	_acc = 0.0
	_emitted = 0
	_burst_count = 0
	_max_travel = 0.0
	_travel_sum = 0.0
	_dead = 0


## Avanza dt segundos. Las chispas nuevas nacen repartidas dentro del paso; los estallidos se resuelven en su
## instante exacto aunque el paso sea largo (a 30 fps un paso dura 33 ms y un estallido, 3-8 ms), y cada chispa
## apagada se guarda una exposición más para dibujar su estela.
func step(dt: float) -> void:
	if dt <= 0.0:
		return
	for i in _age.size():
		_age[i] += dt
	_acc += _rate * dt
	var n := int(floor(_acc))
	_acc -= float(n)
	for k in n:
		if _age.size() >= MAX_SPARKS:
			_acc = 0.0
			break
		_spawn_carrier(_rng.next() * dt)
	# Estallidos pendientes, también los de las recién nacidas y los de las ramas que se añaden en este bucle.
	var i := 0
	while i < _age.size():
		while _next_burst[i] >= 0.0 and _next_burst[i] <= minf(_age[i], _life[i]):
			_burst(i, _next_burst[i])
		i += 1
	i = 0
	while i < _age.size():
		if _age[i] > _life[i] + _keep:
			_kill(i)
		else:
			i += 1


func _kill(i: int) -> void:
	var d := (_pos_at(i, _life[i]) - _p0[i]).length()
	if _gen[i] == 0:
		_max_travel = maxf(_max_travel, d)
		_travel_sum += d
		_dead += 1
	var last := _age.size() - 1
	if i != last:
		_p0[i] = _p0[last]
		_dir[i] = _dir[last]
		_v0[i] = _v0[last]
		_drag[i] = _drag[last]
		_age[i] = _age[last]
		_life[i] = _life[last]
		_temp0[i] = _temp0[last]
		_temp1[i] = _temp1[last]
		_next_burst[i] = _next_burst[last]
		_bursts_left[i] = _bursts_left[last]
		_gen[i] = _gen[last]
	for arr in [_p0, _dir, _v0, _drag, _age, _life, _temp0, _temp1, _next_burst, _bursts_left, _gen]:
		arr.resize(last)


func _append(c: Dictionary) -> void:
	_p0.append(c["p0"])
	_dir.append(c["dir"])
	_v0.append(c["v0"])
	_drag.append(c["drag"])
	_age.append(c["age"])
	_life.append(c["life"])
	_temp0.append(c["t0"])
	_temp1.append(c["t1"])
	_next_burst.append(c["burst"])
	_bursts_left.append(c["bursts_left"])
	_gen.append(c["gen"])


## Nueva chispa «portadora» (la línea recta del haz) nacida hace age0 segundos.
func _spawn_carrier(age0: float) -> void:
	var r := _rng
	var tangent := _axis.cross(_contact - _center)
	if tangent.length_squared() < 1e-14:
		tangent = _axis.cross(Vector3.UP)
	tangent = tangent.normalized() * _spin
	var dir := tangent.rotated(_axis, deg_to_rad(SPREAD_IN_PLANE_DEG) * (2.0 * r.next() - 1.0))
	var side := dir.cross(_axis).normalized()
	dir = dir.rotated(side, deg_to_rad(SPREAD_OUT_PLANE_DEG) * (2.0 * r.next() - 1.0)).normalized()
	var v0 := _vs * lerpf(EJECT_MIN, EJECT_MAX, r.next())
	var into := dir.dot(_normal)
	if into < 0.0:  # rebota en la chapa y pierde velocidad
		dir = (dir - 2.0 * into * _normal).normalized()
		v0 *= 0.6
	var p0 := _contact + _axis * ((r.next() - 0.5) * _kerf) + tangent * ((r.next() - 0.5) * 0.002)
	var life := _life_mean * lerpf(0.55, 1.35, r.next())
	var jitter := (r.next() - 0.5) * 60.0
	var nb := int(floor(_bursts))
	if r.next() < _bursts - float(nb):
		nb += 1
	nb = mini(nb, 4)
	var first := -1.0
	if nb > 0:
		var f := lerpf(0.72, 0.96, r.next()) if _burst_kind == "forked" else lerpf(0.02, 0.25, r.next())
		first = _age_at_fraction(f, v0, DRAG_LENGTH_M, life)
	_append({
		"p0": p0, "dir": dir, "v0": v0, "drag": DRAG_LENGTH_M, "age": age0, "life": life,
		"t0": _t_wheel + jitter, "t1": _t_end + jitter, "burst": first, "bursts_left": nb, "gen": 0,
	})
	_emitted += 1


## Edad a la que la partícula ha recorrido la fracción f de su recorrido total.
static func _age_at_fraction(f: float, v0: float, drag: float, life: float) -> float:
	var total := travel(life, v0, drag)
	return minf(time_to_travel(f * total, v0, drag), life)


## Estallido de la chispa i a la edad tb: en horquilla, la línea se divide en 2-3 ramas cortas y se acaba; en
## estrella (repetidos), suelta 4-7 chispitas en abanico y sigue. Las ramas nacen con la edad que ya tendrían.
func _burst(i: int, tb: float) -> void:
	var age_now := _age[i]
	var r := _rng
	var pos := _pos_at(i, tb)
	var vel := _vel_at(i, tb)
	var speed := maxf(vel.length(), 0.1)
	var d := vel / speed
	var forked := _burst_kind == "forked" or _gen[i] > 0
	var n := (2 + (1 if r.next() < 0.5 else 0)) if forked else (4 + int(r.next() * 4.0))
	var cone := deg_to_rad(22.0 if forked else 65.0)
	var ref := Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
	var ortho := d.cross(ref).normalized()
	var t_here := _temp_at(i, tb)
	for k in n:
		var cd := d.rotated(ortho, cone * sqrt(r.next())).rotated(d, TAU * r.next()).normalized()
		# Los trozos de un estallido son gotitas mucho más pequeñas: frenan en pocos centímetros y se apagan
		# enseguida (por eso se ven como horquillas y estrellas cortas). ESTIMACIÓN visual.
		var life := lerpf(0.008, 0.02, r.next()) if forked else lerpf(0.003, 0.008, r.next())
		var t0 := minf(t_here + 150.0, 1300.0)
		var again := -1.0
		if not forked and _gen[i] == 0 and r.next() < 0.25:
			again = life * lerpf(0.4, 0.8, r.next())
		var child := {
			"p0": pos, "dir": cd, "v0": speed * lerpf(0.35, 0.75, r.next()), "drag": DRAG_LENGTH_M * (0.05 if forked else 0.02),
			"age": age_now - tb, "life": life, "t0": t0, "t1": t0 - 250.0, "burst": again,
			"bursts_left": 1 if again >= 0.0 else 0, "gen": _gen[i] + 1,
		}
		if _age.size() < MAX_SPARKS and age_now - tb <= life + _keep:
			_append(child)
	_burst_count += 1
	if forked and _gen[i] == 0:
		_life[i] = tb  # la línea acaba en la horquilla
		_next_burst[i] = -1.0
		return
	if forked:
		_next_burst[i] = -1.0
		return
	_bursts_left[i] -= 1
	if _bursts_left[i] <= 0:
		_next_burst[i] = -1.0
		return
	var total := travel(_life[i], _v0[i], _drag[i])
	var s_next := travel(tb, _v0[i], _drag[i]) + lerpf(0.08, 0.2, r.next()) * total
	# siempre más tarde que este estallido (si no, el bucle de step() no acabaría)
	_next_burst[i] = maxf(minf(time_to_travel(s_next, _v0[i], _drag[i]), _life[i] + 1.0), tb + 1e-4)


func _pos_at(i: int, t: float) -> Vector3:
	return _p0[i] + _dir[i] * travel(t, _v0[i], _drag[i]) + GRAVITY * (0.5 * t * t)


func _vel_at(i: int, t: float) -> Vector3:
	return _dir[i] * (_v0[i] / (1.0 + _v0[i] * t / _drag[i])) + GRAVITY * t


## Temperatura de la chispa i a la edad t: del color junto al disco al del final del haz y, en el último tramo,
## se enfría hasta apagarse.
func _temp_at(i: int, t: float) -> float:
	var u := clampf(t / maxf(_life[i], 1e-6), 0.0, 1.0)
	var hot := 1.0 - COOL_FRACTION
	if u <= hot:
		return lerpf(_temp0[i], _temp1[i], u / hot)
	return lerpf(_temp1[i], T_DARK_C, (u - hot) / COOL_FRACTION)


## Color (con alfa) de la chispa i a la edad t. Las portadoras nacen con el color del haz que da el modelo y
## cambian al de su temperatura; las ramas de un estallido, con el de su temperatura (más claras).
func color_at(i: int, t: float) -> Color:
	var u := clampf(t / maxf(_life[i], 1e-6), 0.0, 1.0)
	var c := heat_color(_temp_at(i, t))
	if _gen[i] == 0:
		c = _birth_color.lerp(c, clampf(u * 1.6, 0.0, 1.0))
	var fade := clampf((1.0 - u) / COOL_FRACTION, 0.0, 1.0)
	c.a = fade
	return c


# ───────────────────────────── salida ─────────────────────────────


## Búfer del MultiMesh (TRANSFORM_3D, use_colors, use_custom_data): por chispa, una transformación cuyo origen es
## la cabeza de la estela y cuya base X va de la cabeza a la cola (lo recorrido durante `exposure` segundos, como
## lo vería una cámara), base Y perpendicular con longitud = anchura; color RGBA; custom = (u, T/1000, generación,
## variación). La malla es un quad con x ∈ [0, 1] (cabeza → cola) e y ∈ [−0,5, 0,5].
## `capacity`: número de instancias del MultiMesh (el búfer tiene que medir exactamente eso); las que sobran no se
## dibujan si se pone visible_instance_count = count().
func buffer(exposure: float, width: float, capacity: int = 0) -> PackedFloat32Array:
	var n := _age.size()
	_buf.resize(maxi(n, capacity) * FLOATS_PER_SPARK)
	for i in n:
		# Lo que la cámara vio durante la exposición: de max(a − exposición, 0) a min(a, vida).
		var a_head := minf(_age[i], _life[i])
		var a_tail := clampf(_age[i] - exposure, 0.0, a_head)
		var head := _pos_at(i, a_head)
		var tail := _pos_at(i, a_tail)
		var streak := tail - head
		if streak.length() < width:
			var v := _vel_at(i, a_head)
			streak = -v.normalized() * width if v.length_squared() > 0.0 else Vector3(width, 0.0, 0.0)
		var ref := Vector3.UP if absf(streak.normalized().y) < 0.9 else Vector3.RIGHT
		var yb := streak.cross(ref).normalized() * width
		var zb := streak.cross(yb).normalized() * width
		var c := color_at(i, 0.5 * (a_head + a_tail))
		if a_tail >= a_head:
			c.a = 0.0
		var o := i * FLOATS_PER_SPARK
		_buf[o] = streak.x
		_buf[o + 1] = yb.x
		_buf[o + 2] = zb.x
		_buf[o + 3] = head.x
		_buf[o + 4] = streak.y
		_buf[o + 5] = yb.y
		_buf[o + 6] = zb.y
		_buf[o + 7] = head.y
		_buf[o + 8] = streak.z
		_buf[o + 9] = yb.z
		_buf[o + 10] = zb.z
		_buf[o + 11] = head.z
		_buf[o + 12] = c.r
		_buf[o + 13] = c.g
		_buf[o + 14] = c.b
		_buf[o + 15] = c.a
		_buf[o + 16] = clampf(a_head / maxf(_life[i], 1e-6), 0.0, 1.0)
		_buf[o + 17] = _temp_at(i, a_head) / 1000.0
		_buf[o + 18] = float(_gen[i])
		_buf[o + 19] = float(i % 7) / 7.0
	return _buf


## Número de chispas vivas (carriers y ramas).
func count() -> int:
	return _age.size()


## Color medio de las chispas vivas de una generación (0 = portadoras), ponderado por su alfa.
func mean_color(gen: int = 0) -> Color:
	var acc := Color(0, 0, 0, 0)
	var w := 0.0
	for i in _age.size():
		if _gen[i] != gen:
			continue
		var c := color_at(i, _age[i])
		acc += Color(c.r * c.a, c.g * c.a, c.b * c.a, 0.0)
		w += c.a
	if w <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(acc.r / w, acc.g / w, acc.b / w, 1.0)


## Resumen del haz: para los tests y para la interfaz.
func stats() -> Dictionary:
	var live := 0
	var branches := 0
	for i in _age.size():
		if _age[i] > _life[i]:
			continue  # ya apagada: solo queda su estela
		if _gen[i] == 0:
			live += 1
		else:
			branches += 1
	return {
		"family": _family,
		"rate": _rate,
		"length_mm": _length_m * 1000.0,
		"bursts": _bursts,
		"burst_kind": _burst_kind,
		"vs_ms": _vs,
		"life_s": _life_mean,
		"suppressed": _suppressed,
		"alive": live + branches,
		"drawn": _age.size(),
		"carriers": live,
		"branches": branches,
		"emitted": _emitted,
		"burst_events": _burst_count,
		"max_travel_m": _max_travel,
		"mean_travel_m": _travel_sum / float(_dead) if _dead > 0 else 0.0,
	}
