## Taller · materiales de herramienta, recubrimientos y grupos ISO 513 (unidad 5).
##
## TOOL_MATERIALS: { id, name, designation, family, iso513, hv, max_temp_c, coating, iso_groups,
##   vc_range: { grupo ISO: [mín, máx] } (m/min), vc_quality, kvc (factor Kvc del Tabellenbuch), taylor, source,
##   quality }.
##   - vc_range: velocidades de corte orientativas por grupo ISO. Solo las de acero (P) con HSS, metal duro y
##     cerámica salen de la fuente principal (TZ, p. 208); el resto se marca en vc_quality.
##   - taylor: { n, n_by_group, t_ref_min, quality }. El exponente n = −1/k sale de la pendiente k que da el TZ
##     (p. 215) donde existe. C no es una propiedad del material de corte sino del par herramienta-pieza: se deriva
##     de la velocidad central del intervalo, tomada como la de 15 min de vida (vcT15, la referencia del TZ):
##     C = vcT15 · 15^n. Por eso toda la vida de herramienta es una estimación (taylor_params()).
##   - quality (arriba): la peor de las propiedades físicas (props_quality: hv y max_temp_c).
## COATINGS: recubrimientos PVD de Oerlikon Balzers (dureza HV 0,05, temperatura máxima de servicio y color).
## ISO_GROUPS: los seis grupos de ISO 513 con su color, más «O» (fuera de la norma) para vidrio y piedra.
## Constantes de solo lectura; fuentes y estimaciones en docs/taller/fuentes-u5.md.
extends RefCounted

const SRC_ISO513 := "ISO 513:2012, tablas 1-5 (vista previa oficial, iTeh)"
const SRC_BALZERS := (
	"Oerlikon Balzers, folleto corporativo 2007, tabla «Wide range of BALINIT coatings» (HV 0,05; T máx. de servicio; "
	+ "color)"
)
const SRC_TZ_KVC := (
	"Tabellenbuch Zerspantechnik (2015), p. 208: Kvc = 1,2 con HSS (30-60 m/min), 1,0 con metal duro (60-300) y 0,85 "
	+ "con cerámica (180-500)"
)
const SRC_TZ_TAYLOR := (
	"Tabellenbuch Zerspantechnik (2015), p. 215: pendiente k de la recta de vida (acero: HSS −7, metal duro −4, "
	+ "cerámica −2; fundición: metal duro −3,5; aluminio: metal duro −2,5); n = −1/k"
)
const SRC_CTE := (
	"Speiser E., «Understanding hardness», Cutting Tool Engineering 77(5), 2025: metal duro 1300-2000 HV; cerámica "
	+ "2100-2500 HV; CBN ≈ 4500 HV; PCD hasta 6000 HV"
)
const SRC_BOHLER_S600 := (
	"voestalpine BÖHLER, ficha S600 (HS6-5-2C), 2026: curva de revenido (64-66 HRC a 540-560 °C; la dureza cae por "
	+ "encima de ~580 °C) y revenido a 550-570 °C"
)
const SRC_BOHLER_S500 := (
	"voestalpine BÖHLER, ficha S500 (HS2-9-1-8), 2026: curva de revenido (≈ 68-69 HRC a 540-550 °C)"
)
const SRC_E140 := "Conversión HRC → HV con la tabla de ASTM E140 (65 HRC = 832 HV; 68 HRC = 940 HV)"
const SRC_DEW_4301 := (
	"Deutsche Edelstahlwerke, ficha 1.4301 (2007): metal duro recubierto, vc 120/150/200 m/min con ap 6/3/1 mm"
)
const SRC_SANDVIK_CBN := (
	"Sandvik Coromant, Hard part turning 2019 (C-2900-24): CB7105 150-250, CB7115 120-220, CB7125 100-200 y "
	+ "CB7135 80-160 m/min en acero templado (H1.3.Z.HA)"
)
const T_REF_MIN := 15.0  # vida de referencia (vcT15) del Tabellenbuch, p. 215
## Bibliografía del catálogo: la cita completa de cada fuente que resumen los «source» de las entradas
const REFERENCES := [
	SRC_ISO513, SRC_BALZERS, SRC_TZ_KVC, SRC_TZ_TAYLOR, SRC_CTE, SRC_BOHLER_S600, SRC_BOHLER_S500, SRC_E140,
	SRC_DEW_4301, SRC_SANDVIK_CBN,
]

## Grupos de aplicación de ISO 513:2012 (tabla 5). «color» es el color de pantalla (elección de diseño); el
## normativo es «color_name». La norma pinta S de marrón; varios fabricantes (p. ej. Sandvik) lo dibujan naranja.
const ISO_GROUPS := {
	"P": {
		"name": "Acero", "desc": "todos los aceros y aceros moldeados, salvo los inoxidables austeníticos",
		"color_name": "azul", "color": "#2F6BC4", "iso513": true, "source": SRC_ISO513, "quality": "primary",
	},
	"M": {
		"name": "Acero inoxidable", "desc": "inoxidables austeníticos y austenoferríticos, también moldeados",
		"color_name": "amarillo", "color": "#E7C229", "iso513": true, "source": SRC_ISO513, "quality": "primary",
	},
	"K": {
		"name": "Fundición", "desc": "fundición gris, esferoidal y maleable", "color_name": "rojo", "color": "#CC3B31",
		"iso513": true, "source": SRC_ISO513, "quality": "primary",
	},
	"N": {
		"name": "No férreos", "desc": "aluminio y otros metales no férreos, y materiales no metálicos",
		"color_name": "verde", "color": "#2E9D52", "iso513": true, "source": SRC_ISO513, "quality": "primary",
	},
	"S": {
		"name": "Superaleaciones y titanio",
		"desc": "aleaciones refractarias de hierro, níquel y cobalto, y aleaciones de titanio", "color_name": "marrón",
		"color": "#8C5A2E", "iso513": true, "source": SRC_ISO513, "quality": "primary",
	},
	"H": {
		"name": "Materiales duros", "desc": "acero templado, fundición templada y fundición en coquilla",
		"color_name": "gris", "color": "#8B9099", "iso513": true, "source": SRC_ISO513, "quality": "primary",
	},
	"O": {
		"name": "Otros",
		"desc": "fuera de ISO 513: vidrio y piedra, que se cortan con abrasivo o diamante y no con filo definido",
		"color_name": "gris claro", "color": "#C8CCD2", "iso513": false,
		"source": "Convención del simulador (CONTRATOS.md); no es un grupo de ISO 513", "quality": "estimate",
	},
}

## Recubrimientos PVD (Oerlikon Balzers). hv_min = true cuando el fabricante da «más de» (DLC: > 2000 HV).
## mu: coeficiente de fricción contra acero en seco [mín, máx]. «color» es el de pantalla; el real, color_name.
const COATINGS := {
	"tin": {
		"id": "tin", "name": "TiN", "product": "BALINIT A", "hv": 2300.0, "hv_min": false, "max_temp_c": 600.0,
		"mu": [0.4, 0.4], "color_name": "amarillo oro", "color": "#D8B04A", "source": SRC_BALZERS, "quality": "primary",
	},
	"ticn": {
		"id": "ticn", "name": "TiCN", "product": "BALINIT B", "hv": 3000.0, "hv_min": false, "max_temp_c": 400.0,
		"mu": [0.4, 0.4], "color_name": "gris azulado", "color": "#71809A", "source": SRC_BALZERS, "quality": "primary",
	},
	"tialn": {
		"id": "tialn", "name": "TiAlN", "product": "BALINIT FUTURA NANO", "hv": 3300.0, "hv_min": false, "max_temp_c": 900.0,
		"mu": [0.3, 0.35], "color_name": "gris violeta", "color": "#6D5F87", "source": SRC_BALZERS, "quality": "primary",
	},
	"alcrn": {
		"id": "alcrn", "name": "AlCrN", "product": "BALINIT ALCRONA", "hv": 3200.0, "hv_min": false, "max_temp_c": 1100.0,
		"mu": [0.35, 0.35], "color_name": "gris azulado", "color": "#5E7394", "source": SRC_BALZERS, "quality": "primary",
	},
	"dlc": {
		"id": "dlc", "name": "DLC (a-C:H)", "product": "BALINIT DLC", "hv": 2000.0, "hv_min": true, "max_temp_c": 350.0,
		"mu": [0.1, 0.2], "color_name": "negro", "color": "#1F1F24", "source": SRC_BALZERS, "quality": "primary",
	},
}

const TOOL_MATERIALS := [
	{
		"id": "hss_m2",
		"name": "Acero rápido HSS M2",
		"designation": "HS6-5-2C · 1.3343 (AISI M2)",
		"family": "hss",
		"iso513": null,
		"hv": 832.0,
		"max_temp_c": 600.0,
		"coating": null,
		"props_quality": { "hv": "secondary", "max_temp_c": "secondary" },
		"iso_groups": ["P", "M", "K", "N", "S"],
		"vc_range": { "P": [30.0, 60.0], "M": [15.0, 30.0], "K": [20.0, 40.0], "N": [60.0, 150.0], "S": [10.0, 25.0] },
		"vc_quality": { "P": "primary", "M": "estimate", "K": "estimate", "N": "estimate", "S": "estimate" },
		"kvc": 1.2,
		"kvc_quality": "primary",
		"taylor": {
			"n": 1.0 / 7.0, "n_by_group": {}, "n_quality": { "P": "primary" }, "t_ref_min": T_REF_MIN, "quality": "estimate",
		},
		"source": "HV: 65 HRC en la curva de revenido de BÖHLER S600 (64-66 HRC) → 832 HV (ASTM E140). Temperatura: se "
			+ "reviene a 550-570 °C y pierde dureza por encima de ~580-600 °C (misma ficha). vc en acero y Kvc: TZ, p. 208. "
			+ "n: TZ, p. 215.",
		"quality": "secondary",
	},
	{
		"id": "hss_co_m42",
		"name": "Acero rápido al cobalto HSS-Co M42",
		"designation": "HS2-9-1-8 · 1.3247 (AISI M42)",
		"family": "hss",
		"iso513": null,
		"hv": 940.0,
		"max_temp_c": 600.0,
		"coating": null,
		"props_quality": { "hv": "secondary", "max_temp_c": "secondary" },
		"iso_groups": ["P", "M", "K", "N", "S"],
		"vc_range": { "P": [30.0, 60.0], "M": [15.0, 30.0], "K": [20.0, 40.0], "N": [60.0, 150.0], "S": [10.0, 25.0] },
		"vc_quality": { "P": "primary", "M": "estimate", "K": "estimate", "N": "estimate", "S": "estimate" },
		"kvc": 1.2,
		"kvc_quality": "primary",
		"taylor": {
			"n": 1.0 / 7.0, "n_by_group": {}, "n_quality": { "P": "primary" }, "t_ref_min": T_REF_MIN, "quality": "estimate",
		},
		"source": "HV: ≈ 68 HRC en la curva de revenido de BÖHLER S500 → 940 HV (ASTM E140); el cobalto le da más dureza "
			+ "en caliente. Temperatura: revenido a 550-570 °C (misma ficha). vc en acero y Kvc: los de HSS del TZ, p. 208 "
			+ "(el TZ no distingue el HSS-Co). n: TZ, p. 215.",
		"quality": "secondary",
	},
	{
		"id": "hss_tin",
		"name": "HSS M2 con TiN («broca de titanio»)",
		"designation": "HS6-5-2C + TiN PVD",
		"family": "hss",
		"iso513": null,
		"hv": 832.0,
		"max_temp_c": 600.0,
		"coating": "tin",
		"props_quality": { "hv": "secondary", "max_temp_c": "secondary" },
		"iso_groups": ["P", "M", "K", "N", "S"],
		"vc_range": { "P": [30.0, 60.0], "M": [15.0, 30.0], "K": [20.0, 40.0], "N": [60.0, 150.0], "S": [10.0, 25.0] },
		"vc_quality": { "P": "primary", "M": "estimate", "K": "estimate", "N": "estimate", "S": "estimate" },
		"kvc": 1.2,
		"kvc_quality": "primary",
		"taylor": {
			"n": 1.0 / 7.0, "n_by_group": {}, "n_quality": { "P": "primary" }, "t_ref_min": T_REF_MIN, "quality": "estimate",
		},
		"source": "Las «brocas de titanio» de consumo son HSS con una capa fina de TiN (nitruro de titanio), no de "
			+ "titanio. Sustrato: el HSS M2 (832 HV). Capa: TiN de 2300 HV y 600 °C (Balzers). La capa alarga la vida, pero "
			+ "sin un dato publicado accesible no se modela: mismas vc y n que el HSS.",
		"quality": "secondary",
	},
	{
		"id": "hm",
		"name": "Metal duro sin recubrir",
		"designation": "HW (WC-Co), grados P, M, K, N y S de ISO 513",
		"family": "carbide",
		"iso513": "HW",
		"hv": 1650.0,
		"max_temp_c": 1000.0,
		"coating": null,
		"props_quality": { "hv": "secondary", "max_temp_c": "estimate" },
		"iso_groups": ["P", "M", "K", "N", "S"],
		"vc_range": { "P": [60.0, 300.0], "M": [60.0, 150.0], "K": [60.0, 250.0], "N": [200.0, 800.0], "S": [30.0, 80.0] },
		"vc_quality": { "P": "primary", "M": "estimate", "K": "estimate", "N": "estimate", "S": "estimate" },
		"kvc": 1.0,
		"kvc_quality": "primary",
		"taylor": {
			"n": 0.25, "n_by_group": { "K": 1.0 / 3.5, "N": 0.4 },
			"n_quality": { "P": "primary", "K": "primary", "N": "primary" }, "t_ref_min": T_REF_MIN, "quality": "estimate",
		},
		"source": "HV: centro del intervalo 1300-2000 HV del metal duro (Speiser, Cutting Tool Engineering 2025). "
			+ "Temperatura ≈ 1000 °C: valor de manual sin fuente accesible verificada (estimación). vc en acero y Kvc: TZ, "
			+ "p. 208. n (acero, fundición, aluminio): TZ, p. 215.",
		"quality": "estimate",
	},
	{
		"id": "hm_coated",
		"name": "Metal duro recubierto (PVD TiAlN)",
		"designation": "HC, grados P, M, K y S de ISO 513",
		"family": "carbide",
		"iso513": "HC",
		"hv": 1650.0,
		"max_temp_c": 900.0,
		"coating": "tialn",
		"props_quality": { "hv": "secondary", "max_temp_c": "secondary" },
		"iso_groups": ["P", "M", "K", "S"],
		"vc_range": { "P": [60.0, 300.0], "M": [120.0, 200.0], "K": [80.0, 300.0], "S": [30.0, 80.0] },
		"vc_quality": { "P": "primary", "M": "secondary", "K": "estimate", "S": "estimate" },
		"kvc": 1.0,
		"kvc_quality": "primary",
		"taylor": {
			"n": 0.25, "n_by_group": { "K": 1.0 / 3.5 }, "n_quality": { "P": "primary", "K": "primary" },
			"t_ref_min": T_REF_MIN, "quality": "estimate",
		},
		"source": "Sustrato: el metal duro (1650 HV). Capa TiAlN de 3300 HV y 900 °C (Balzers), que limita la temperatura. "
			+ "vc en acero y Kvc: TZ, p. 208 (el TZ no distingue recubiertos). vc en inoxidable: ficha 1.4301 de DEW "
			+ "(120-200 m/min). n: TZ, p. 215. Los grados CVD (TiCN + Al2O3) no se modelan aparte.",
		"quality": "secondary",
	},
	{
		"id": "cermet",
		"name": "Cermet",
		"designation": "HT (TiCN-Ni/Co), ISO 513",
		"family": "cermet",
		"iso513": "HT",
		"hv": 1600.0,
		"max_temp_c": 1000.0,
		"coating": null,
		"props_quality": { "hv": "estimate", "max_temp_c": "estimate" },
		"iso_groups": ["P", "M", "K"],
		"vc_range": { "P": [100.0, 350.0], "M": [100.0, 250.0], "K": [100.0, 300.0] },
		"vc_quality": { "P": "estimate", "M": "estimate", "K": "estimate" },
		"kvc": 1.0,
		"kvc_quality": "estimate",
		"taylor": { "n": 0.25, "n_by_group": {}, "n_quality": {}, "t_ref_min": T_REF_MIN, "quality": "estimate" },
		"source": "Estimación: sin ficha accesible verificada. HV y temperatura del orden del metal duro (entre 1400 y "
			+ "1800 HV); se usa sobre todo para acabar acero a velocidades altas. Kvc y n: los del metal duro del TZ (el TZ "
			+ "no trata el cermet).",
		"quality": "estimate",
	},
	{
		"id": "ceramica_al2o3",
		"name": "Cerámica de alúmina (óxido y mixta)",
		"designation": "CA / CM (Al2O3, Al2O3 + TiC), ISO 513",
		"family": "ceramic",
		"iso513": "CA",
		"hv": 2300.0,
		"max_temp_c": 1200.0,
		"coating": null,
		"props_quality": { "hv": "secondary", "max_temp_c": "estimate" },
		"iso_groups": ["P", "K", "H"],
		"vc_range": { "P": [180.0, 500.0], "K": [200.0, 600.0], "H": [60.0, 200.0] },
		"vc_quality": { "P": "primary", "K": "estimate", "H": "estimate" },
		"kvc": 0.85,
		"kvc_quality": "primary",
		"taylor": {
			"n": 0.5, "n_by_group": {}, "n_quality": { "P": "primary" }, "t_ref_min": T_REF_MIN, "quality": "estimate",
		},
		"source": "HV: centro del intervalo 2100-2500 HV de la cerámica de corte (Speiser, Cutting Tool Engineering 2025). "
			+ "Temperatura ≈ 1200 °C: estimación. vc en acero y Kvc: TZ, p. 208. n en acero: TZ, p. 215.",
		"quality": "estimate",
	},
	{
		"id": "ceramica_si3n4",
		"name": "Cerámica de nitruro de silicio",
		"designation": "CN (Si3N4, SiAlON), ISO 513",
		"family": "ceramic",
		"iso513": "CN",
		"hv": 1600.0,
		"max_temp_c": 1200.0,
		"coating": null,
		"props_quality": { "hv": "estimate", "max_temp_c": "estimate" },
		"iso_groups": ["K", "S"],
		"vc_range": { "K": [180.0, 500.0], "S": [150.0, 300.0] },
		"vc_quality": { "K": "secondary", "S": "estimate" },
		"kvc": 0.85,
		"kvc_quality": "primary",
		"taylor": { "n": 0.5, "n_by_group": {}, "n_quality": {}, "t_ref_min": T_REF_MIN, "quality": "estimate" },
		"source": "Estimación de HV (más blanda y más tenaz que la alúmina) y de temperatura, sin ficha accesible "
			+ "verificada. vc en fundición: el intervalo de cerámica del TZ (p. 208). Kvc: TZ, p. 208. n: el de la cerámica "
			+ "en acero del TZ (p. 215), supuesto.",
		"quality": "estimate",
	},
	{
		"id": "cbn",
		"name": "CBN (nitruro de boro cúbico policristalino)",
		"designation": "BH / BL, ISO 513",
		"family": "cbn",
		"iso513": "BH",
		"hv": 4500.0,
		"max_temp_c": 1300.0,
		"coating": null,
		"props_quality": { "hv": "secondary", "max_temp_c": "estimate" },
		"iso_groups": ["H", "K"],
		"vc_range": { "H": [80.0, 250.0], "K": [300.0, 800.0] },
		"vc_quality": { "H": "secondary", "K": "estimate" },
		"kvc": 0.85,
		"kvc_quality": "estimate",
		"taylor": { "n": 0.5, "n_by_group": {}, "n_quality": {}, "t_ref_min": T_REF_MIN, "quality": "estimate" },
		"source": "HV ≈ 4500 (Speiser, Cutting Tool Engineering 2025). vc en acero templado: grados CB7105-CB7135 de "
			+ "Sandvik (80-250 m/min; Hard part turning 2019). Temperatura, Kvc (el de la cerámica) y n: estimaciones.",
		"quality": "estimate",
	},
	{
		"id": "pcd",
		"name": "PCD (diamante policristalino)",
		"designation": "DP, ISO 513",
		"family": "pcd",
		"iso513": "DP",
		"hv": 6000.0,
		"max_temp_c": 600.0,
		"coating": null,
		"props_quality": { "hv": "secondary", "max_temp_c": "secondary" },
		"iso_groups": ["N"],
		"vc_range": { "N": [300.0, 1500.0] },
		"vc_quality": { "N": "estimate" },
		"kvc": 0.85,
		"kvc_quality": "estimate",
		"taylor": { "n": 0.4, "n_by_group": {}, "n_quality": {}, "t_ref_min": T_REF_MIN, "quality": "estimate" },
		"source": "HV: hasta 6000 HV (Speiser, Cutting Tool Engineering 2025). 600 °C: temperatura máxima de servicio del "
			+ "diamante policristalino de Balzers (BALINIT DIAMOND); por encima se grafitiza y se oxida, y el hierro lo "
			+ "disuelve (no sirve para acero). vc, Kvc y n (el del metal duro en aluminio, TZ p. 215): estimaciones.",
		"quality": "secondary",
	},
]


## La herramienta por id ({} si no existe). Devuelve la constante: es de solo lectura.
static func get_tool(id: String) -> Dictionary:
	for t in TOOL_MATERIALS:
		if t["id"] == id:
			return t
	return {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for t in TOOL_MATERIALS:
		out.append(t["id"])
	return out


static func get_coating(id: String) -> Dictionary:
	return COATINGS.get(id, {})


## ¿Recomienda el catálogo esta herramienta para el grupo ISO?
static func recommended(tool: Dictionary, group: String) -> bool:
	return tool.get("iso_groups", []).has(group)


## Dureza de la superficie de trabajo (la de la capa si la hay).
static func surface_hv(tool: Dictionary) -> float:
	var c = tool.get("coating")
	if c != null and COATINGS.has(c):
		return COATINGS[c]["hv"]
	return tool["hv"]


## Parámetros de Taylor (vc·T^n = C) de la herramienta en un grupo ISO: { n, C, vc_ref, t_ref_min, quality,
## n_quality, source }. vc_ref es el centro del intervalo de vc, tomado como vcT15. Vacío si el grupo no está.
static func taylor_params(tool: Dictionary, group: String) -> Dictionary:
	var vr = tool.get("vc_range", {}).get(group)
	if vr == null:
		return {}
	var t: Dictionary = tool["taylor"]
	var n: float = t["n_by_group"].get(group, t["n"])
	var vc_ref: float = (float(vr[0]) + float(vr[1])) / 2.0
	var t_ref: float = t["t_ref_min"]
	return {
		"n": n,
		"C": vc_ref * pow(t_ref, n),
		"vc_ref": vc_ref,
		"t_ref_min": t_ref,
		"quality": "estimate",
		"n_quality": t["n_quality"].get(group, "estimate"),
		"source": "n: %s. C = vcT15·15^n con vcT15 = centro de vc_range (estimación)" % SRC_TZ_TAYLOR,
	}
