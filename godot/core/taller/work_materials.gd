## Taller · materiales de pieza (unidad 5).
##
## Cada entrada cumple el contrato «Material de pieza» de CONTRATOS.md:
##   { id, name, iso, kind, density (kg/m³), hv, rm (MPa), kc: { kc11, mc, gamma0, family } | null, source, quality }
## y añade lo que necesita el modelo de corte:
##   - designation: designación normalizada y estado de suministro que se ha supuesto.
##   - rm_max: límite superior de Rm cuando la norma da un intervalo (null si solo hay mínimo).
##   - props_quality: calidad de cada propiedad física. «quality» (arriba) es la peor de las tres, y «source» cita
##     de dónde sale cada una. rm es el MÍNIMO que garantiza la norma para ese estado y tamaño.
##   - kc: coeficientes de Kienzle de UNA sola familia de fuentes (el Tabellenbuch Zerspantechnik, TZ), con su
##     propia source/quality, las fuerzas de avance y pasiva (kf11, mf, kp11, mp), valores alternativos del mismo
##     libro (alt) y los datos de Sandvik con los que se deriva una segunda familia (sandvik). Las alternativas no
##     se mezclan con la principal: solo sirven para la banda de incertidumbre (la dispersión entre fuentes).
##   - kc_reason: por qué kc es null (materiales que no se cortan con filo definido en este modelo).
## Los catálogos son constantes de solo lectura: quien quiera modificarlos, que use .duplicate(true).
## Fuentes completas y tabla de estimaciones: docs/taller/fuentes-u5.md.
extends RefCounted

const FAMILY_TZ := "tabellenbuch"
## Referencia principal de la unidad (extracto oficial de las pp. 199-215, «Grundlagen der Zerspantechnik»)
const SRC_TZ := "Tabellenbuch Zerspantechnik, 1.ª ed., Europa-Lehrmittel, 2015 (ISBN 978-3-8085-1473-3)"
## Segunda familia (solo para la banda): constante K de potencia de Sandvik, calculada con ηmt = 0,8
const SRC_SANDVIK_K := (
	"Sandvik Coromant, Metalcutting Technical Guide (D) Milling, 2005, p. D26 (constante K, ae/Dc = 0,8)"
)
const QUALITIES := ["primary", "secondary", "estimate"]
const KINDS := [
	"acero", "inox", "fundicion", "aluminio", "laton", "titanio", "niquel", "madera", "plastico", "piedra", "vidrio",
]
const ISO_LETTERS := ["P", "M", "K", "N", "S", "H", "O"]

## Derivación de la familia de Sandvik a partir de su tabla de K (Pc = ap·ae·vf·K/100 000, en el motor):
## kc = 600·η·K con η = 0,8 (nota 1 de la tabla) y hm de una fresa centrada de κ = 45° (la del ejemplo de la
## guía; supuesto) con ae/Dc = 0,8. Da kc a 0° de desprendimiento (γ0 = 0), que es la base de Sandvik.
const SANDVIK_ETA := 0.8
const SANDVIK_AE_DC := 0.8
const SANDVIK_KAPPA_DEG := 45.0
const SANDVIK_FZ := [0.1, 0.2, 0.4]

const WORK_MATERIALS := [
	{
		"id": "s235jr",
		"name": "Acero S235JR",
		"designation": "S235JR · 1.0038 · EN 10025-2, laminado",
		"iso": "P",
		"kind": "acero",
		"density": 7850.0,
		"hv": 112.0,
		"rm": 360.0,
		"rm_max": 510.0,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "secondary" },
		"source": "Rm 360-510 MPa y ReH ≥ 235 MPa (variante JR de EN 10025-2, t ≥ 3 mm): thyssenkrupp Steel, "
			+ "información de producto S235JR (otra transcripción, WinSteel, da 350-510). HV ≈ 112: convertida desde "
			+ "Rm = 360 MPa con la tabla de ISO 18265. Densidad 7850 kg/m³: EN 1993-1-1, 3.2.6.",
		"quality": "estimate",
		"kc": {
			"kc11": 1780.0, "mc": 0.17, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 209, tabla 1 (S235JR)",
			"quality": "primary",
			"kf11": null, "mf": null, "kp11": null, "mp": null,
			"alt": [
				{
					"kc11": 1800.0, "mc": 0.2, "gamma0": 6.0,
					"source": "TZ, p. 207, grupo P «aceros de construcción blandos, bajo C» (Rm < 450)", "quality": "secondary",
				},
			],
			"sandvik": { "cmc": "01.1", "k": [5.7, 4.8, 4.0] },
		},
	},
	{
		"id": "c45e",
		"name": "Acero C45E normalizado",
		"designation": "C45E +N · 1.1191 · EN 10083-2",
		"iso": "P",
		"kind": "acero",
		"density": 7850.0,
		"hv": 181.0,
		"rm": 580.0,
		"rm_max": null,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "primary" },
		"source": "Rm ≥ 580 MPa (+N, 16 < d ≤ 100 mm): EN 10083-2:2006, tabla 9. HV ≈ 181: convertida desde Rm con la "
			+ "tabla de ISO 18265. Densidad 7850 kg/m³: EN 1993-1-1, 3.2.6.",
		"quality": "estimate",
		"kc": {
			# El TZ trae dos filas de C45E: 1850/0,14 (tabla 1, p. 209) y 2200/0,14 (p. 211, con kf y kp, la misma
			# del ejemplo resuelto de la p. 205). Se usa la segunda porque es la familia completa (kc, kf, kp); la
			# primera va a la banda.
			"kc11": 2200.0, "mc": 0.14, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 211 (tabla de kc, kf y kp) y ejemplo de la p. 205",
			"quality": "primary",
			"kf11": 370.0, "mf": 0.73, "kp11": 310.0, "mp": 0.43,
			"kfp_source": "TZ, p. 211", "kfp_quality": "primary",
			"alt": [
				{
					"kc11": 1850.0, "mc": 0.14, "gamma0": 6.0, "source": "TZ, p. 209, tabla 1 (otra fila de C45E)",
					"quality": "primary",
				},
				{
					"kc11": 2000.0, "mc": 0.2, "gamma0": 6.0,
					"source": "TZ, p. 207, grupo P «no aleados, C < 0,5 %, bonificación» (Rm < 550)", "quality": "secondary",
				},
			],
			"sandvik": { "cmc": "01.2", "k": [6.1, 5.1, 4.3] },
		},
	},
	{
		"id": "c16mncr5",
		"name": "Acero de cementación 16MnCr5",
		"designation": "16MnCr5 +FP · 1.7131 · EN 10084",
		"iso": "P",
		"kind": "acero",
		"density": 7850.0,
		"hv": 172.0,
		"rm": 550.0,
		"rm_max": null,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "estimate" },
		"source": "+FP: 140-187 HBW (EN 10084:2008, vía SteelNumber). HV ≈ 172 (dureza media / 0,95) y Rm ≈ 550 MPa: "
			+ "conversiones de ISO 18265. Densidad 7850 kg/m³: EN 1993-1-1, 3.2.6.",
		"quality": "estimate",
		"kc": {
			"kc11": 2100.0, "mc": 0.26, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 209, tabla 1, y p. 211 (16MnCr5)",
			"quality": "primary",
			"kf11": 390.0, "mf": 0.7, "kp11": 325.0, "mp": 0.46,
			"kfp_source": "TZ, p. 211", "kfp_quality": "primary",
			"alt": [
				{
					"kc11": 2200.0, "mc": 0.24, "gamma0": 6.0,
					"source": "TZ, p. 207, grupo P «baja aleación, cementación y bonificación» (Rm < 700)", "quality": "secondary",
				},
			],
			"sandvik": { "cmc": "02.1", "k": [6.5, 5.4, 4.6] },
		},
	},
	{
		"id": "c42crmo4",
		"name": "Acero bonificado 42CrMo4",
		"designation": "42CrMo4 +QT · 1.7225 · EN 10083-3",
		"iso": "P",
		"kind": "acero",
		"density": 7850.0,
		"hv": 280.0,
		"rm": 900.0,
		"rm_max": 1100.0,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "primary" },
		"source": "Rm 900-1100 MPa, Re ≥ 650 MPa (+QT, 40 < d ≤ 100 mm): EN 10083-3:2006, tabla 8. HV ≈ 280: convertida "
			+ "desde Rm = 900 MPa con ISO 18265. Densidad 7850 kg/m³: EN 1993-1-1, 3.2.6.",
		"quality": "estimate",
		"kc": {
			"kc11": 2500.0, "mc": 0.26, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, pp. 208, 209 y 211 (42CrMo4; ejemplo resuelto de la p. 208)",
			"quality": "primary",
			"kf11": 340.0, "mf": 0.67, "kp11": 270.0, "mp": 0.48,
			"kfp_source": "TZ, p. 211", "kfp_quality": "primary",
			"alt": [
				{
					"kc11": 2500.0, "mc": 0.27, "gamma0": 6.0, "source": "TZ, p. 207, grupo P «bonificación más duros» (Rm < 900)",
					"quality": "secondary",
				},
			],
			"sandvik": { "cmc": "02.2", "k": [7.6, 6.4, 5.4] },
		},
	},
	{
		"id": "x5crni18_10",
		"name": "Inoxidable austenítico X5CrNi18-10",
		"designation": "X5CrNi18-10 +AT · 1.4301 (AISI 304) · EN 10088-3",
		"iso": "M",
		"kind": "inox",
		"density": 7900.0,
		"hv": 205.0,
		"rm": 500.0,
		"rm_max": 700.0,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "secondary" },
		"source": "Rm 500-700 MPa, ≤ 215 HB (típico 195 HB) y 7,90 kg/dm³: EN 10088-3, vía ficha 1.4301 de Deutsche "
			+ "Edelstahlwerke (2007). HV ≈ 205: 195 HB / 0,95.",
		"quality": "estimate",
		"kc": {
			"kc11": 2350.0, "mc": 0.21, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 210, tabla 2 (X5CrNi18-10)",
			"quality": "primary",
			# kf y kp: la fila de la p. 211 más próxima es otro austenítico (X10CrNiMo18-10)
			"kf11": 200.0, "mf": 0.75, "kp11": 180.0, "mp": 0.6,
			"kfp_source": "TZ, p. 211 (X10CrNiMo18-10, austenítico vecino)", "kfp_quality": "secondary",
			"alt": [
				{
					"kc11": 2000.0, "mc": 0.2, "gamma0": 6.0, "source": "TZ, p. 207, grupo M «inoxidables austeníticos»",
					"quality": "secondary",
				},
			],
			"sandvik": { "cmc": "05.21", "k": [6.9, 6.0, 5.2] },
		},
	},
	{
		"id": "gjl250",
		"name": "Fundición gris EN-GJL-250",
		"designation": "EN-GJL-250 · EN-JL1040 · EN 1561",
		"iso": "K",
		"kind": "fundicion",
		"density": 7200.0,
		"hv": 210.0,
		"rm": 250.0,
		"rm_max": 350.0,
		"props_quality": { "density": "estimate", "hv": "estimate", "rm": "secondary" },
		"source": "Rm 250-350 MPa: EN 1561, vía ficha EN-GJL-250 de NovaCast. Densidad ≈ 7200 kg/m³ y ≈ 210 HV (≈ 200 HB): "
			+ "valores típicos de la fundición gris, sin ficha consultada (estimación).",
		"quality": "estimate",
		"kc": {
			"kc11": 1160.0, "mc": 0.26, "gamma0": 2.0, "family": FAMILY_TZ,
			"source": "TZ, p. 210, tabla 2, y p. 211 (GJL-250); γ0 = +2° para fundición (p. 208)",
			"quality": "primary",
			"kf11": 250.0, "mf": 0.7, "kp11": 190.0, "mp": 0.46,
			"kfp_source": "TZ, p. 211", "kfp_quality": "primary",
			"alt": [
				{
					"kc11": 1050.0, "mc": 0.23, "gamma0": 2.0, "source": "TZ, p. 207, grupo K «fundición gris, GJL»",
					"quality": "secondary",
				},
			],
			"sandvik": { "cmc": "08.1", "k": [3.7, 3.0, 2.5] },
		},
	},
	{
		"id": "al6082_t6",
		"name": "Aluminio EN AW-6082 T6",
		"designation": "EN AW-6082 T6 · AlSi1MgMn · EN 755-2",
		"iso": "N",
		"kind": "aluminio",
		"density": 2700.0,
		"hv": 100.0,
		"rm": 310.0,
		"rm_max": null,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "secondary" },
		"source": "Rm ≥ 310 MPa, Rp0,2 ≥ 260 MPa, 95 HB y 2,70 g/cm³: EN 755-2, vía ficha 6082-T6 de Aalco. HV ≈ 100: 95 "
			+ "HB / 0,95.",
		"quality": "estimate",
		"kc": {
			# El extracto del TZ no trae el 6082: se usa el valor del grupo N (aleaciones de Al de buena
			# maquinabilidad), por eso es «secondary». Las aleaciones de forja de la tabla 2 van a la banda.
			"kc11": 470.0, "mc": 0.27, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 207, grupo N «no férreos de buena maquinabilidad, aluminio» (no hay fila del 6082)",
			"quality": "secondary",
			"kf11": 20.0, "mf": 1.08, "kp11": 32.0, "mp": 0.75,
			"kfp_source": "TZ, p. 211 (AlMg4SiMn, aleación de forja vecina)", "kfp_quality": "secondary",
			"alt": [
				{
					"kc11": 510.0, "mc": 0.28, "gamma0": 6.0, "source": "TZ, p. 210, tabla 2 (AlCu4Mg1, forja bonificable)",
					"quality": "secondary",
				},
				{
					"kc11": 487.0, "mc": 0.23, "gamma0": 6.0, "source": "TZ, p. 210, tabla 2 (AlMg4,5Mn0,4, forja)",
					"quality": "secondary",
				},
			],
			"sandvik": { "cmc": "30.12", "k": [2.5, 2.1] },
		},
	},
	{
		"id": "cuzn39pb3",
		"name": "Latón de mecanizado CuZn39Pb3",
		"designation": "CuZn39Pb3 R430 · CW614N · EN 12164",
		"iso": "N",
		"kind": "laton",
		"density": 8470.0,
		"hv": 120.0,
		"rm": 430.0,
		"rm_max": null,
		"props_quality": { "density": "primary", "hv": "secondary", "rm": "secondary" },
		"source": "Densidad 8,47 g/cm³; varilla R430 (Ø 2-40 mm) de EN 12164: Rm ≥ 430 MPa y ≈ 120 HB/HV (valor "
			+ "informativo): Deutsches Kupferinstitut, ficha CuZn39Pb3 (2005).",
		"quality": "secondary",
		"kc": {
			"kc11": 780.0, "mc": 0.18, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 210, tabla 2 (CuZn39Pb2, latón vecino con algo menos de plomo)",
			"quality": "secondary",
			"kf11": null, "mf": null, "kp11": null, "mp": null,
			"alt": [
				{
					"kc11": 470.0, "mc": 0.27, "gamma0": 6.0,
					"source": "TZ, p. 207, grupo N «no férreos de buena maquinabilidad, latón»", "quality": "secondary",
				},
			],
			"sandvik": { "cmc": "33.1", "k": [2.1, 1.8] },
		},
	},
	{
		"id": "ti6al4v",
		"name": "Titanio Ti-6Al-4V recocido",
		"designation": "Ti-6Al-4V grado 5 · 3.7165 · ASTM B348, recocido",
		"iso": "S",
		"kind": "titanio",
		"density": 4430.0,
		"hv": 318.0,
		"rm": 895.0,
		"rm_max": null,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "secondary" },
		"source": "Densidad 0,160 lb/in³ = 4,43 g/cm³ (la misma ficha imprime 4,47) y 30-34 HRC recocido: ATI, ficha "
			+ "Ti-6Al-4V (2012). HV ≈ 318: 32 HRC con la tabla de ASTM E140 (de aceros; aproximada). Rm ≥ 895 MPa: mínimo de "
			+ "ASTM B348 grado 5, vía fichas de suministradores.",
		"quality": "estimate",
		"kc": {
			"kc11": 1370.0, "mc": 0.21, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 210, tabla 2 (TiAl6V4)",
			"quality": "primary",
			"kf11": null, "mf": null, "kp11": null, "mp": null,
			"alt": [
				{
					"kc11": 1400.0, "mc": 0.22, "gamma0": 6.0, "source": "TZ, p. 207, grupo S «aleaciones de titanio»",
					"quality": "secondary",
				},
			],
			"sandvik": { "cmc": "23.21", "k": [5.1, 4.3] },
		},
	},
	{
		"id": "inconel718",
		"name": "Inconel 718 envejecido",
		"designation": "NiCr19Fe19Nb5Mo3 · 2.4668 (UNS N07718), solubilizado y envejecido",
		"iso": "S",
		"kind": "niquel",
		"density": 8220.0,
		"hv": 390.0,
		"rm": 1240.0,
		"rm_max": null,
		"props_quality": { "density": "secondary", "hv": "estimate", "rm": "secondary" },
		"source": "Envejecido: 8,22 g/cm³ y Rm ≥ 1240 MPa (180 ksi): United Performance Metals, ficha de la aleación 718 "
			+ "(AMS 5596/5662). HV ≈ 390: estimación para ~40 HRC, típico del envejecido.",
		"quality": "estimate",
		"kc": {
			# El extracto del TZ no trae el 718: valor del grupo S (Ni, > 30 HRC), por eso es «secondary»
			"kc11": 3200.0, "mc": 0.24, "gamma0": 6.0, "family": FAMILY_TZ,
			"source": "TZ, p. 207, grupo S «aleaciones de Ni y Co, aceros refractarios, > 30 HRC» (no hay fila del 718)",
			"quality": "secondary",
			"kf11": 340.0, "mf": 0.7, "kp11": 560.0, "mp": 0.4,
			"kfp_source": "TZ, p. 211 (NiCr20TiAl, aleación de níquel vecina)", "kfp_quality": "secondary",
			"alt": [
				{
					"kc11": 2088.0, "mc": 0.29, "gamma0": 6.0, "source": "TZ, p. 210, tabla 2 (NiCr20TiAl, otra aleación de níquel)",
					"quality": "secondary",
				},
			],
			"sandvik": { "cmc": "20.22", "k": [11.0, 9.3] },
		},
	},
	{
		"id": "pino",
		"name": "Madera de pino silvestre",
		"designation": "Pinus sylvestris, seca (12 % de humedad)",
		"iso": "N",
		"kind": "madera",
		"density": 550.0,
		"hv": 2.5,
		"rm": null,
		"rm_max": null,
		"rm_note": "Sin Rm comparable al de un metal: depende de la dirección de la fibra (módulo de rotura a flexión 83,3 "
			+ "MPa).",
		"props_quality": { "density": "secondary", "hv": "secondary", "rm": "secondary" },
		"source": "Densidad seca media 550 kg/m³, dureza Janka 2420 N (≈ 24 MPa ≈ 2,5 HV, la misma conversión que el "
			+ "laboratorio) y MOR 83,3 MPa: The Wood Database, Scots pine.",
		"quality": "secondary",
		"kc": null,
		"kc_reason": "La madera no tiene kc1.1 en la familia de referencia: su corte depende de la dirección de la fibra y "
			+ "de la humedad y se describe con otros modelos (fuerza por unidad de anchura). El simulador no calcula fuerzas "
			+ "de corte en madera.",
	},
	{
		"id": "pvc",
		"name": "PVC rígido (PVC-U)",
		"designation": "PVC-U, placa o barra extruida",
		"iso": "N",
		"kind": "plastico",
		"density": 1400.0,
		"hv": 15.0,
		"rm": 50.0,
		"rm_max": null,
		"props_quality": { "density": "estimate", "hv": "estimate", "rm": "estimate" },
		"source": "Estimación: valores típicos del PVC-U (1,38-1,45 g/cm³, Rm ≈ 50 MPa) sin ficha de fabricante "
			+ "consultada; HV por analogía con el ABS del laboratorio (16 HV).",
		"quality": "estimate",
		"kc": null,
		"kc_reason": "Termoplástico: su resistencia al corte cambia mucho con la temperatura y la velocidad, y no hay "
			+ "kc1.1 en la familia de referencia. El simulador no calcula fuerzas de corte en plásticos.",
	},
	{
		"id": "abs",
		"name": "Plástico ABS",
		"designation": "ABS de inyección o placa",
		"iso": "N",
		"kind": "plastico",
		"density": 1050.0,
		"hv": 16.0,
		"rm": 40.0,
		"rm_max": null,
		"props_quality": { "density": "estimate", "hv": "secondary", "rm": "estimate" },
		"source": "16 HV: el mismo valor típico que el laboratorio (docs/FISICA.md). Densidad ≈ 1,05 g/cm³ y Rm ≈ 40 MPa: "
			+ "valores típicos sin ficha consultada (estimación).",
		"quality": "estimate",
		"kc": null,
		"kc_reason": "Termoplástico: su resistencia al corte cambia mucho con la temperatura y la velocidad, y no hay "
			+ "kc1.1 en la familia de referencia. El simulador no calcula fuerzas de corte en plásticos.",
	},
	{
		"id": "vidrio",
		"name": "Vidrio sodocálcico (float)",
		"designation": "Vidrio float recocido, EN 572-1",
		"iso": "O",
		"kind": "vidrio",
		"density": 2500.0,
		"hv": 550.0,
		"rm": null,
		"rm_max": null,
		"rm_note": "Frágil: no tiene Rm útil. Resistencia característica a flexión 45 MPa (EN 572-1).",
		"props_quality": { "density": "secondary", "hv": "secondary", "rm": "secondary" },
		"source": "Densidad 2500 kg/m³ y fg,k 45 MPa: EN 572-1 (vía Saint-Gobain, como el laboratorio). 550 HV: el mismo "
			+ "valor típico del laboratorio (docs/FISICA.md).",
		"quality": "secondary",
		"kc": null,
		"kc_reason": "Material frágil: no forma viruta con un filo definido. Se corta con abrasivo o diamante (radial) y "
			+ "se rompe por flexión; no hay kc en este modelo.",
	},
	{
		"id": "granito",
		"name": "Granito",
		"designation": "Roca ígnea: feldespato, cuarzo y mica",
		"iso": "O",
		"kind": "piedra",
		"density": 2650.0,
		"hv": 900.0,
		"rm": null,
		"rm_max": null,
		"rm_note": "Roca frágil y heterogénea: sin Rm útil.",
		"props_quality": { "density": "estimate", "hv": "estimate", "rm": "estimate" },
		"source": "Estimación: densidad típica de los granitos comerciales (2600-2700 kg/m³); HV intermedia entre sus "
			+ "minerales (cuarzo ≈ 1100 HV, el mismo valor que la encimera de cuarzo del laboratorio, y feldespato algo más "
			+ "blando).",
		"quality": "estimate",
		"kc": null,
		"kc_reason": "Roca frágil y heterogénea: se corta con disco diamantado o abrasivo, no con filo definido. No hay kc "
			+ "en este modelo.",
	},
]


## El material por id ({} si no existe). Devuelve la constante: es de solo lectura.
static func get_material(id: String) -> Dictionary:
	for m in WORK_MATERIALS:
		if m["id"] == id:
			return m
	return {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for m in WORK_MATERIALS:
		out.append(m["id"])
	return out


## Los materiales con kc (los que el modelo sabe cortar).
static func machinable_ids() -> Array[String]:
	var out: Array[String] = []
	for m in WORK_MATERIALS:
		if m["kc"] != null:
			out.append(m["id"])
	return out


## Familia de Sandvik derivada de la tabla de K: { kc11, mc, gamma0 = 0 } por mínimos cuadrados en log-log.
## k = valores de K para fz = 0,1 / 0,2 / 0,4 mm (los que haya). Ver SANDVIK_* arriba.
static func sandvik_family(k: Array) -> Dictionary:
	var shape := sin(deg_to_rad(SANDVIK_KAPPA_DEG)) * SANDVIK_AE_DC / asin(SANDVIK_AE_DC)
	var xs: Array[float] = []
	var ys: Array[float] = []
	for i in mini(k.size(), SANDVIK_FZ.size()):
		var hm: float = SANDVIK_FZ[i] * shape
		xs.append(log(hm))
		ys.append(log(600.0 * SANDVIK_ETA * float(k[i])))
	var n := xs.size()
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += xs[i] / n
		my += ys[i] / n
	var sxy := 0.0
	var sxx := 0.0
	for i in n:
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
	var slope := sxy / sxx
	return { "kc11": exp(my - slope * mx), "mc": -slope, "gamma0": 0.0 }


## Todas las familias de kc de un material: la principal y después las alternativas (TZ y Sandvik).
## Cada una: { kc11, mc, gamma0, source, quality, main: bool }. Vacío si el material no tiene kc.
static func kc_families(material: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kc = material.get("kc")
	if kc == null:
		return out
	out.append({
		"kc11": kc["kc11"], "mc": kc["mc"], "gamma0": kc["gamma0"], "source": kc["source"], "quality": kc["quality"],
		"main": true,
	})
	for a in kc.get("alt", []):
		out.append({
			"kc11": a["kc11"], "mc": a["mc"], "gamma0": a["gamma0"], "source": a["source"], "quality": a["quality"],
			"main": false,
		})
	var sv = kc.get("sandvik")
	if sv != null:
		var fam := sandvik_family(sv["k"])
		fam["source"] = "%s, CMC %s (derivado)" % [SRC_SANDVIK_K, sv["cmc"]]
		fam["quality"] = "estimate"
		fam["main"] = false
		out.append(fam)
	return out


## Fuerzas de avance y pasiva de Kienzle: { kf11, mf, kp11, mp, source, quality }.
## Si el TZ no las da para ese material, regla de la p. 211 («en aceros de resistencia media, kf1.1 ≈ kc1.1/5 y
## kp1.1 ≈ kc1.1/6») con los exponentes medianos de esa misma tabla (mf = 0,70 y mp = 0,48): estimación.
static func force_components(material: Dictionary) -> Dictionary:
	var kc = material.get("kc")
	if kc == null:
		return {}
	if kc.get("kf11") != null:
		var src := "%s — %s" % [SRC_TZ, str(kc.get("kfp_source", "p. 211"))]
		return {
			"kf11": kc["kf11"], "mf": kc["mf"], "kp11": kc["kp11"], "mp": kc["mp"], "source": src,
			"quality": kc.get("kfp_quality", "primary"),
		}
	return {
		"kf11": float(kc["kc11"]) / 5.0, "mf": 0.70, "kp11": float(kc["kc11"]) / 6.0, "mp": 0.48,
		"source": "Regla del TZ (p. 211): kf1.1 ≈ kc1.1/5 y kp1.1 ≈ kc1.1/6, válida en aceros de resistencia media; "
			+ "exponentes: medianas de la tabla de la p. 211",
		"quality": "estimate",
	}
