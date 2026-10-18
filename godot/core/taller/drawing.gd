## Taller · planos de las piezas de ejemplo y tolerancias ISO (unidad 5).
##
## Un plano es un diccionario:
##   { id, name, material (id de work_materials.gd), stock: { d_mm, length_mm, in_chuck_mm, face_allowance_mm },
##     general_tolerance, ra_general_um, contour, features, ra, source }
##   - contour: el perfil nominal, de la cara (Z0) hacia el plato, como tramos
##     { kind: "line" | "arc", z_hi, z_lo, … }.
##     line: r_hi en z_hi y r_lo en z_lo (constante si son iguales). arc: centro (cz, cr) y radio; concave = true es
##     un redondeo de rincón (el material queda por debajo del arco). raw = true marca el bruto sin mecanizar.
##     En un escalón (z en el borde de dos tramos) el radio es el del tramo mayor: la cara del hombro es material.
##   - features (cotas): { id, kind: "diameter" | "length" | "chamfer" | "radius" | "cone", label, nominal (mm),
##     z_from, z_to, tol: { upper_um, lower_um }, iso }. En el cono, nominal es el diámetro en z_to y nominal_from
##     el de z_from. Las longitudes se acotan desde la cara (z_from = 0), como las cotas absolutas del programa.
##     Roscas (fase 2): "thread_major" (Ø exterior d), "thread_pitch_diameter" (Ø medio d2), "thread_minor" (Ø de
##     fondo d3), "thread_pitch" (paso P) y "thread_length" (rosca completa desde la cara), todas en la zona de la
##     rosca [z_to, z_from]. Los tramos del contorno con thread = true son la zona roscada: su «nominal» es el Ø
##     torneado antes de roscar, y la banda de tolerancia va del fondo mínimo al exterior máximo.
##   - thread (si la pieza tiene rosca): { designation, pitch_mm, d_mm, d2_mm, d3_mm, h3_mm, z_from, z_to, source }.
##   - ra: zonas { zone, z_from, z_to, required_um, general } (general = sale de la nota general del plano).
## Coordenadas del torno (CONTRATOS.md): Z = 0 en la cara acabada y la pieza en Z < 0; r en radio.
## Rejilla del perfil: el anillo i está en z = z0 + i·dz (ver profile_grid()).
extends RefCounted

const NO_PLAN := -1.0  # radio de la banda de un anillo que el plano no acota (igual que lathe_mesh.gd)
const ISO286_SOURCE := (
	"ISO 286-2:2010, tabla 1 (valores de ISO 286-1:2010) y figura 2 (h: es = 0, ei = −IT; js: ±IT/2)"
)
const ISO2768_SOURCE := (
	"ISO 2768-1:1989, tabla 1 (longitudes, también radios interiores) y tabla 2 (aristas: chaflanes y radios "
	+ "exteriores), vía AmesWeb"
)
const ISO965_SOURCE := (
	"ISO 965-1 (rosca métrica ISO, clase 6g: desviación fundamental es = −(15 + 11·P) µm; Td(6) = 335 µm y "
	+ "Td2(6) = 170 µm para M20×2,5), con los límites de M20×2,5-6g de ASME B1.13M vía AmesWeb: d 19,958/19,623, "
	+ "d2 18,334/18,164, d3 16,891/16,624; perfil básico de ISO 68-1 (H = 0,866·P, h3 = 0,6134·P)"
)
## Error de paso admisible (derivado): ISO 965-1 no tolera el paso aparte, lo absorbe Td2; el diámetro equivalente de
## un error de paso ΔP en una rosca de 60° es 1,732·ΔP (cot 30°), así que ΔP ≤ Td2/1,732.
const PITCH_SOURCE := "Derivado de ISO 965-1: ΔP ≤ Td2/cot 30° = 0,170/1,732 = 0,098 mm (el error de paso cabe en Td2)"
## Límite superior (incluido) de cada grupo de tamaño nominal de ISO 286 hasta 120 mm (el primero empieza en 0)
const IT_SIZES := [3.0, 6.0, 10.0, 18.0, 30.0, 50.0, 80.0, 120.0]
## Tolerancias fundamentales IT6-IT11 en µm (ISO 286-1:2010, tabla 1; reproducida en ISO 286-2:2010, tabla 1)
const IT_TABLE := {
	6: [6, 8, 9, 11, 13, 16, 19, 22],
	7: [10, 12, 15, 18, 21, 25, 30, 35],
	8: [14, 18, 22, 27, 33, 39, 46, 54],
	9: [25, 30, 36, 43, 52, 62, 74, 87],
	10: [40, 48, 58, 70, 84, 100, 120, 140],
	11: [60, 75, 90, 110, 130, 160, 190, 220],
}
## ISO 2768-1, tabla 1: diferencias admisibles (± mm) por clase, para medidas de 0,5 a 3 mm, de más de 3 a 6…
const ISO2768_LINEAR := [
	[0.5, 3.0, { "f": 0.05, "m": 0.1, "c": 0.2, "v": null }],
	[3.0, 6.0, { "f": 0.05, "m": 0.1, "c": 0.3, "v": 0.5 }],
	[6.0, 30.0, { "f": 0.1, "m": 0.2, "c": 0.5, "v": 1.0 }],
	[30.0, 120.0, { "f": 0.15, "m": 0.3, "c": 0.8, "v": 1.5 }],
	[120.0, 400.0, { "f": 0.2, "m": 0.5, "c": 1.2, "v": 2.5 }],
	[400.0, 1000.0, { "f": 0.3, "m": 0.8, "c": 2.0, "v": 4.0 }],
	[1000.0, 2000.0, { "f": 0.5, "m": 1.2, "c": 3.0, "v": 6.0 }],
	[2000.0, 4000.0, { "f": null, "m": 2.0, "c": 4.0, "v": 8.0 }],
]
## ISO 2768-1, tabla 2: aristas rotas (radios exteriores y alturas de chaflán)
const ISO2768_EDGES := [
	[0.5, 3.0, { "f": 0.2, "m": 0.2, "c": 0.4, "v": 0.4 }],
	[3.0, 6.0, { "f": 0.5, "m": 0.5, "c": 1.0, "v": 1.0 }],
	[6.0, INF, { "f": 1.0, "m": 1.0, "c": 2.0, "v": 2.0 }],
]
const EPS := 1e-9
const DZ_DEFAULT := 0.02


## Tolerancia fundamental ITn (µm) para un tamaño nominal (mm). NAN fuera de la tabla (IT6-IT11, hasta 120 mm).
## Los grupos son «de más de a hasta, incluido»: 30 mm cae en 18-30.
static func it_um(grade: int, nominal_mm: float) -> float:
	if not IT_TABLE.has(grade) or nominal_mm <= 0.0 or nominal_mm > IT_SIZES[IT_SIZES.size() - 1]:
		return NAN
	for i in IT_SIZES.size():
		if nominal_mm <= IT_SIZES[i]:
			return float(IT_TABLE[grade][i])
	return NAN


## Clase de tolerancia de un eje, como «h9» o «js9»: { upper_um, lower_um, it_um, code, source }. {} si no se
## conoce la letra o el grado. Solo h y js (las del prototipo). js es ±IT/2 exacto, sin redondear los IT impares.
static func shaft_tolerance(code: String, nominal_mm: float) -> Dictionary:
	var letter := code.rstrip("0123456789")
	var grade_text := code.substr(letter.length())
	if grade_text == "" or not grade_text.is_valid_int():
		return {}
	var it := it_um(int(grade_text), nominal_mm)
	if is_nan(it):
		return {}
	match letter:
		"h":
			return { "upper_um": 0.0, "lower_um": -it, "it_um": it, "code": code, "source": ISO286_SOURCE }
		"js":
			return { "upper_um": it / 2.0, "lower_um": -it / 2.0, "it_um": it, "code": code, "source": ISO286_SOURCE }
	return {}


## Tolerancia general de ISO 2768-1 para una medida sin tolerancia propia: { upper_um, lower_um, code, source }.
## kind: "linear" (longitudes, diámetros y radios interiores) o "edge" (chaflanes y radios exteriores).
## {} por debajo de 0,5 mm (la norma pide indicarla junto a la cota) o si la clase no tiene valor.
static func general_tolerance(kind: String, nominal_mm: float, cls: String = "m") -> Dictionary:
	var table: Array = ISO2768_EDGES if kind == "edge" else ISO2768_LINEAR
	for i in table.size():
		var row: Array = table[i]
		var above_low: bool = nominal_mm > float(row[0]) or (i == 0 and nominal_mm >= float(row[0]))
		var inside: bool = nominal_mm <= float(row[1]) and above_low
		if inside:
			var v = row[2].get(cls)
			if v == null:
				return {}
			var um: float = float(v) * 1000.0
			return { "upper_um": um, "lower_um": -um, "code": "ISO 2768-%s" % cls, "source": ISO2768_SOURCE }
	return {}


## Banda de tolerancia por anillo para la capa de desviación de la malla 3D (lathe_mesh.gd): { z0, dz, r_min, r_max }
## con n anillos en z = z0 + i·dz. En los tramos rectos de un diámetro acotado, su tolerancia ISO 286; en el resto
## del contorno (chaflanes, radios, conos), la general del plano (ISO 2768) sobre el diámetro local; fuera de la
## pieza (delante de la cara) y en el bruto sin mecanizar, NO_PLAN (−1): el plano no pide nada.
static func tolerance_band(drawing: Dictionary, z0: float, dz: float, n: int) -> Dictionary:
	var r_min := PackedFloat64Array()
	var r_max := PackedFloat64Array()
	r_min.resize(n)
	r_max.resize(n)
	var cls := String(drawing.get("general_tolerance", "ISO 2768-m")).get_slice("-", 1)
	for i in n:
		var z := z0 + i * dz
		r_min[i] = NO_PLAN
		r_max[i] = NO_PLAN
		var seg: Variant = null
		for s in drawing["contour"]:
			if z <= float(s["z_hi"]) + EPS and z >= float(s["z_lo"]) - EPS:
				seg = s
				break
		if seg == null or seg.get("raw", false):
			continue
		var r := nominal_radius(drawing, z)
		if seg.get("thread", false) and drawing.has("thread"):
			# zona roscada: del Ø de fondo mínimo al exterior máximo (los dientes en V están dentro)
			r_min[i] = float(drawing["thread"]["d3_min_mm"]) / 2.0
			r_max[i] = float(drawing["thread"]["d_max_mm"]) / 2.0
			continue
		var tol := {}
		if seg["kind"] == "line" and absf(float(seg["r_hi"]) - float(seg["r_lo"])) < EPS:
			for f in drawing["features"]:
				if f["kind"] == "diameter" and absf(float(f["nominal"]) / 2.0 - r) < EPS \
						and z <= maxf(f["z_from"], f["z_to"]) + EPS and z >= minf(f["z_from"], f["z_to"]) - EPS:
					tol = f["tol"]
					break
		if tol.is_empty():
			tol = general_tolerance("linear", 2.0 * r, cls)
		if tol.is_empty():
			continue
		r_min[i] = r + float(tol["lower_um"]) / 2000.0
		r_max[i] = r + float(tol["upper_um"]) / 2000.0
	return { "z0": z0, "dz": dz, "r_min": r_min, "r_max": r_max }


## Los planos de las piezas de ejemplo: A y B de CONTRATOS.md y C de la fase 2 (se construyen en cada llamada: el
## diccionario es del que lo pide).
static func drawings() -> Array[Dictionary]:
	return [drawing_a(), drawing_b(), drawing_c()]


static func get_drawing(id: String) -> Dictionary:
	for d in drawings():
		if d["id"] == id:
			return d
	return {}


## Pieza A · eje escalonado de C45E (CONTRATOS.md): bruto Ø50 × 85 con 25 mm en el plato; chaflán 1×45°;
## Ø30 h9 de Z0 a Z−20, Ø40 h9 de Z−20 a Z−40, Ø46 ±0,1 de Z−40 a Z−55; Ra 3,2 general y 1,6 en el Ø40.
## De Z−55 al plato (Z−60) queda un collar de bruto Ø50.
static func drawing_a() -> Dictionary:
	return {
		"id": "A",
		"name": "Eje escalonado",
		"material": "c45e",
		"stock": { "d_mm": 50.0, "length_mm": 85.0, "in_chuck_mm": 25.0, "face_allowance_mm": 1.0 },
		"general_tolerance": "ISO 2768-m",
		"ra_general_um": 3.2,
		"contour": [
			{ "kind": "line", "z_hi": 0.0, "z_lo": -1.0, "r_hi": 14.0, "r_lo": 15.0 },
			{ "kind": "line", "z_hi": -1.0, "z_lo": -20.0, "r_hi": 15.0, "r_lo": 15.0 },
			{ "kind": "line", "z_hi": -20.0, "z_lo": -40.0, "r_hi": 20.0, "r_lo": 20.0 },
			{ "kind": "line", "z_hi": -40.0, "z_lo": -55.0, "r_hi": 23.0, "r_lo": 23.0 },
			{ "kind": "line", "z_hi": -55.0, "z_lo": -85.0, "r_hi": 25.0, "r_lo": 25.0, "raw": true },
		],
		"features": [
			_feature("A-CH1", "chamfer", "Chaflán 1×45°", 1.0, 0.0, -1.0, general_tolerance("edge", 1.0),
				{ "angle_deg": 45.0 }),
			_feature("A-D30", "diameter", "Ø30 h9", 30.0, 0.0, -20.0, shaft_tolerance("h9", 30.0)),
			_feature("A-D40", "diameter", "Ø40 h9", 40.0, -20.0, -40.0, shaft_tolerance("h9", 40.0)),
			_feature("A-D46", "diameter", "Ø46 ±0,1", 46.0, -40.0, -55.0,
				{ "upper_um": 100.0, "lower_um": -100.0, "code": "±0,1", "source": "Cota del plano (CONTRATOS.md)" }),
			_feature("A-L20", "length", "20 (cara-hombro del Ø40)", 20.0, 0.0, -20.0, general_tolerance("linear", 20.0)),
			_feature("A-L40", "length", "40 (cara-hombro del Ø46)", 40.0, 0.0, -40.0, general_tolerance("linear", 40.0)),
			_feature("A-L55", "length", "55 (cara-fin del Ø46)", 55.0, 0.0, -55.0, general_tolerance("linear", 55.0)),
		],
		"ra": [
			{ "zone": "A-D30", "z_from": -1.0, "z_to": -20.0, "required_um": 3.2, "general": true },
			{ "zone": "A-D40", "z_from": -20.0, "z_to": -40.0, "required_um": 1.6, "general": false },
			{ "zone": "A-D46", "z_from": -40.0, "z_to": -55.0, "required_um": 3.2, "general": true },
		],
		"source": "Pieza A de godot/CONTRATOS.md. Tolerancias: ISO 286 (h9) e ISO 2768-m (el resto). Las longitudes "
			+ "se acotan desde la cara.",
	}


## Pieza B · bulón de EN AW-6082 T6 (CONTRATOS.md): bruto Ø40 × 70 con 20 mm en el plato; chaflán 0,5×45°;
## Ø24 h8 de Z0 a Z−15 con un redondeo cóncavo R2 en el hombro; Ø36 js9 de Z−15 a Z−35; cono de Ø36 a Ø38 de
## Z−35 a Z−45; Ra 1,6 en el Ø24. El Ra 3,2 del resto es la nota general (elección del plano, como en la pieza A).
static func drawing_b() -> Dictionary:
	return {
		"id": "B",
		"name": "Bulón",
		"material": "al6082_t6",
		"stock": { "d_mm": 40.0, "length_mm": 70.0, "in_chuck_mm": 20.0, "face_allowance_mm": 1.0 },
		"general_tolerance": "ISO 2768-m",
		"ra_general_um": 3.2,
		"contour": [
			{ "kind": "line", "z_hi": 0.0, "z_lo": -0.5, "r_hi": 11.5, "r_lo": 12.0 },
			{ "kind": "line", "z_hi": -0.5, "z_lo": -13.0, "r_hi": 12.0, "r_lo": 12.0 },
			{ "kind": "arc", "z_hi": -13.0, "z_lo": -15.0, "cz": -13.0, "cr": 14.0, "radius": 2.0, "concave": true },
			{ "kind": "line", "z_hi": -15.0, "z_lo": -35.0, "r_hi": 18.0, "r_lo": 18.0 },
			{ "kind": "line", "z_hi": -35.0, "z_lo": -45.0, "r_hi": 18.0, "r_lo": 19.0 },
			{ "kind": "line", "z_hi": -45.0, "z_lo": -70.0, "r_hi": 20.0, "r_lo": 20.0, "raw": true },
		],
		"features": [
			_feature("B-CH05", "chamfer", "Chaflán 0,5×45°", 0.5, 0.0, -0.5, general_tolerance("edge", 0.5),
				{ "angle_deg": 45.0 }),
			_feature("B-D24", "diameter", "Ø24 h8", 24.0, 0.0, -15.0, shaft_tolerance("h8", 24.0)),
			_feature("B-R2", "radius", "R2 (redondeo del hombro)", 2.0, -13.0, -15.0, general_tolerance("linear", 2.0),
				{ "concave": true }),
			_feature("B-D36", "diameter", "Ø36 js9", 36.0, -15.0, -35.0, shaft_tolerance("js9", 36.0)),
			_feature("B-CONE", "cone", "Cono Ø36 → Ø38", 38.0, -35.0, -45.0, general_tolerance("linear", 38.0),
				{ "nominal_from": 36.0 }),
			_feature("B-L15", "length", "15 (cara-hombro)", 15.0, 0.0, -15.0, general_tolerance("linear", 15.0)),
			_feature("B-L35", "length", "35 (cara-inicio del cono)", 35.0, 0.0, -35.0, general_tolerance("linear", 35.0)),
			_feature("B-L45", "length", "45 (cara-fin del cono)", 45.0, 0.0, -45.0, general_tolerance("linear", 45.0)),
		],
		"ra": [
			{ "zone": "B-D24", "z_from": -0.5, "z_to": -13.0, "required_um": 1.6, "general": false },
			{ "zone": "B-D36", "z_from": -15.0, "z_to": -35.0, "required_um": 3.2, "general": true },
			{ "zone": "B-CONE", "z_from": -35.0, "z_to": -45.0, "required_um": 3.2, "general": true },
		],
		"source": "Pieza B de godot/CONTRATOS.md. Tolerancias: ISO 286 (h8, js9) e ISO 2768-m (el resto; R2 es un "
			+ "radio interior: tabla 1). Ra 3,2 general: elección del plano.",
	}


## Pieza C · tornillo M20×2,5-6g de C45E (fase 2, docs/taller/fagor-fase2.md): bruto Ø30 × 75 con 25 mm en el
## plato. Chaflán de entrada de la rosca 1,5×45° (del Ø16,79 al Ø19,79), rosca M20×2,5-6g con 20 mm de rosca completa
## como mínimo desde la cara (la salida de rosca llega a Z−25), cuello Ø19,79 hasta Z−32, Ø26 ±0,1 de Z−32 a Z−45 y
## collar de bruto Ø30 hasta el plato. El Ø exterior se tornea al centro de su tolerancia 6g (19,79).
static func drawing_c() -> Dictionary:
	var p := 2.5
	var h := 0.8660254037844386 * p  # H = √3/2·P (ISO 68-1)
	var t_d := { "upper_um": -42.0, "lower_um": -377.0, "code": "6g", "source": ISO965_SOURCE }
	var t_d2 := { "upper_um": -42.0, "lower_um": -212.0, "code": "6g", "source": ISO965_SOURCE }
	var t_d3 := { "upper_um": -42.0, "lower_um": -309.0, "code": "6g", "source": ISO965_SOURCE }
	var d := 20.0
	var d2 := d - 0.75 * h  # d − 2·(3H/8)
	var d3 := d - 2.0 * (17.0 / 24.0) * h  # d − 2·h3, h3 = 17H/24 = 0,6134·P
	return {
		"id": "C",
		"name": "Tornillo M20×2,5",
		"material": "c45e",
		"stock": { "d_mm": 30.0, "length_mm": 75.0, "in_chuck_mm": 25.0, "face_allowance_mm": 1.0 },
		"general_tolerance": "ISO 2768-m",
		"ra_general_um": 3.2,
		"contour": [
			{ "kind": "line", "z_hi": 0.0, "z_lo": -1.5, "r_hi": 8.395, "r_lo": 9.895, "thread": true },
			{ "kind": "line", "z_hi": -1.5, "z_lo": -25.0, "r_hi": 9.895, "r_lo": 9.895, "thread": true },
			{ "kind": "line", "z_hi": -25.0, "z_lo": -32.0, "r_hi": 9.895, "r_lo": 9.895 },
			{ "kind": "line", "z_hi": -32.0, "z_lo": -45.0, "r_hi": 13.0, "r_lo": 13.0 },
			{ "kind": "line", "z_hi": -45.0, "z_lo": -75.0, "r_hi": 15.0, "r_lo": 15.0, "raw": true },
		],
		"thread": {
			"designation": "M20×2,5-6g", "pitch_mm": p, "d_mm": d, "d2_mm": d2, "d3_mm": d3, "h3_mm": (17.0 / 24.0) * h,
			"d_max_mm": d + t_d["upper_um"] / 1000.0, "d3_min_mm": d3 + t_d3["lower_um"] / 1000.0,
			"z_from": 0.0, "z_to": -25.0, "source": ISO965_SOURCE,
		},
		"features": [
			_feature("C-M20-D", "thread_major", "M20 d (Ø exterior)", d, 0.0, -25.0, t_d),
			_feature("C-M20-D2", "thread_pitch_diameter", "M20 d2 (Ø medio)", d2, 0.0, -25.0, t_d2),
			_feature("C-M20-D3", "thread_minor", "M20 d3 (Ø de fondo)", d3, 0.0, -25.0, t_d3),
			_feature("C-M20-P", "thread_pitch", "M20 P (paso)", p, 0.0, -25.0,
				{ "upper_um": 98.0, "lower_um": -98.0, "code": "Td2/1,732", "source": PITCH_SOURCE }),
			_feature("C-M20-L", "thread_length", "Rosca completa (mín. 20)", 20.0, 0.0, -25.0,
				{ "upper_um": 5000.0, "lower_um": 0.0, "code": "mín. 20", "source": "Cota del plano de la pieza C" }),
			_feature("C-D26", "diameter", "Ø26 ±0,1", 26.0, -32.0, -45.0,
				{ "upper_um": 100.0, "lower_um": -100.0, "code": "±0,1", "source": "Cota del plano de la pieza C" }),
			_feature("C-L32", "length", "32 (cara-hombro del Ø26)", 32.0, 0.0, -32.0, general_tolerance("linear", 32.0)),
			_feature("C-L45", "length", "45 (cara-fin del Ø26)", 45.0, 0.0, -45.0, general_tolerance("linear", 45.0)),
		],
		"ra": [
			{ "zone": "C-CUELLO", "z_from": -25.0, "z_to": -32.0, "required_um": 3.2, "general": true },
			{ "zone": "C-D26", "z_from": -32.0, "z_to": -45.0, "required_um": 3.2, "general": true },
		],
		"source": "Pieza C de la fase 2 (docs/taller/fagor-fase2.md). Rosca: ISO 68-1 e ISO 965-1 (6g). El resto: ISO "
			+ "2768-m; Ra 3,2 general, elección del plano. Las longitudes se acotan desde la cara.",
	}


static func _feature(id: String, kind: String, label: String, nominal: float, z_from: float, z_to: float,
		tol: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var f := {
		"id": id, "kind": kind, "label": label, "nominal": nominal, "z_from": z_from, "z_to": z_to,
		"tol": { "upper_um": tol.get("upper_um", NAN), "lower_um": tol.get("lower_um", NAN) },
		"iso": tol.get("code", ""),
		"tol_source": tol.get("source", ""),
	}
	f.merge(extra)
	return f


## Radio de un tramo del contorno en z (z dentro del tramo).
static func segment_radius(seg: Dictionary, z: float) -> float:
	var zh: float = seg["z_hi"]
	var zl: float = seg["z_lo"]
	var zc := clampf(z, zl, zh)
	if seg["kind"] == "arc":
		var dz: float = zc - float(seg["cz"])
		var rad: float = seg["radius"]
		var root := sqrt(maxf(rad * rad - dz * dz, 0.0))
		return float(seg["cr"]) - root if seg.get("concave", true) else float(seg["cr"]) + root
	var rh: float = seg["r_hi"]
	var rl: float = seg["r_lo"]
	if zh - zl <= EPS:
		return maxf(rh, rl)
	return rl + (rh - rl) * (zc - zl) / (zh - zl)


## Radio nominal (mm) en z: el mayor de los tramos que contienen z (en un escalón manda la cara del hombro); 0
## fuera de la pieza.
static func nominal_radius(drawing: Dictionary, z: float) -> float:
	var r := 0.0
	for seg in drawing["contour"]:
		if z <= float(seg["z_hi"]) + EPS and z >= float(seg["z_lo"]) - EPS:
			r = maxf(r, segment_radius(seg, z))
	return r


## Intervalo [mín, máx] del radio nominal en z ∈ [za, zb] (cada tramo es monótono: bastan sus extremos). Los
## trozos de [za, zb] fuera del contorno cuentan como radio 0.
static func nominal_range(drawing: Dictionary, za: float, zb: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var zmin := INF
	var zmax := -INF
	for seg in drawing["contour"]:
		var sl: float = seg["z_lo"]
		var sh: float = seg["z_hi"]
		zmin = minf(zmin, sl)
		zmax = maxf(zmax, sh)
		var a := maxf(za, sl)
		var b := minf(zb, sh)
		if a > b + EPS:
			continue
		var ra := segment_radius(seg, a)
		var rb := segment_radius(seg, b)
		lo = minf(lo, minf(ra, rb))
		hi = maxf(hi, maxf(ra, rb))
	if za < zmin - EPS or zb > zmax + EPS:
		lo = minf(lo, 0.0)
		hi = maxf(hi, 0.0)
	if lo > hi:
		return Vector2.ZERO
	return Vector2(lo, hi)


## Rejilla por defecto: del extremo del bruto dentro del plato (z0) a la cara del bruto, con paso dz.
static func profile_grid(drawing: Dictionary, dz: float = DZ_DEFAULT) -> Dictionary:
	var st: Dictionary = drawing["stock"]
	var z_max: float = st.get("face_allowance_mm", 0.0)
	var z0: float = z_max - float(st["length_mm"])
	return { "z0": z0, "dz": dz, "count": int(roundf((z_max - z0) / dz)) + 1 }


## Radio nominal por anillo (mm) en la rejilla del contrato: el anillo i está en z = z0 + i·dz. Sin z0 ni count,
## la rejilla de profile_grid().
static func target_profile(drawing: Dictionary, dz: float = DZ_DEFAULT, z0: float = NAN,
		count: int = -1) -> PackedFloat64Array:
	var g := profile_grid(drawing, dz)
	if is_nan(z0):
		z0 = g["z0"]
	if count < 0:
		count = g["count"]
	var r := PackedFloat64Array()
	r.resize(count)
	for i in count:
		r[i] = nominal_radius(drawing, z0 + i * dz)
	return r


## Un perfil completo del contrato con la pieza terminada al nominal (útil para la vista previa del plano y para
## los tests): ring_pass 2 (acabado) donde el nominal es menor que el bruto, y ring_ra = ra_um donde además queda
## superficie; los anillos sin material (el refrentado) no tienen Ra.
static func make_profile(drawing: Dictionary, dz: float = DZ_DEFAULT, ra_um: float = 0.0, z0: float = NAN,
		count: int = -1) -> Dictionary:
	var g := profile_grid(drawing, dz)
	if is_nan(z0):
		z0 = g["z0"]
	if count < 0:
		count = g["count"]
	var r := target_profile(drawing, dz, z0, count)
	var stock_r: float = float(drawing["stock"]["d_mm"]) / 2.0
	var ring_ra := PackedFloat32Array()
	var ring_pass := PackedByteArray()
	ring_ra.resize(count)
	ring_pass.resize(count)
	for i in count:
		var machined := r[i] < stock_r - EPS
		ring_ra[i] = ra_um if machined and r[i] > EPS else 0.0
		ring_pass[i] = 2 if machined else 0
	return { "z0": z0, "dz": dz, "r": r, "ring_ra": ring_ra, "ring_pass": ring_pass, "dirty": Vector2i(0, count - 1) }
