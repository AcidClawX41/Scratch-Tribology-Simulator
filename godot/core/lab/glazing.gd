## Tribología biológica · vidrios de coche: ventanilla templada y parabrisas laminado (modelo 2.0, unidad 1f).
##
## Dos objetivos nuevos para el catálogo 2.0 y su comportamiento. Especificación y fuentes:
## docs/fisica/pulido-materiales.md (tema 6).
##   - Templado: el temple deja una compresión en las caras que equilibra una tracción en el centro, con un perfil
##     casi parabólico: σ(ζ) = ½·σS·(1 − 3ζ²), la compresión de la superficie es el doble de la tracción del centro
##     y se anula a un 21 % del espesor (Nielsen, Schneider & Kraus 2022). Estalla entero en cuanto (a) la flexión
##     llega a su resistencia característica, 120 MPa (EN 12150-1), o (b) una grieta de contacto atraviesa la capa
##     comprimida y llega a la zona en tracción. La energía elástica almacenada, U_D = (1−ν)·σS²/(5E), fija el
##     tamaño de los trozos: δ = 122,1 J/m² / U_D (Nielsen et al. 2022, ec. 2 y 4).
##   - Laminado: dos hojas de vidrio recocido pegadas a una lámina de PVB. El vidrio se agrieta como el recocido,
##     pero la lámina sujeta los trozos: no cae. Para atravesarlo hace falta romper también el PVB.
## La flexión de la hoja la calcula physics.gd con pane_break() (Roark, apartado 15 de FISICA.md) y la recibe aquí
## como dato: este módulo no la copia (ni precarga physics.gd, que en la 2.0 precargará este).
## Unidades: N · mm · MPa · GPa · J. Funciones puras, deterministas y seguras para hilos.
## Uso: const Glazing = preload("res://core/lab/glazing.gd").
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const Fracture = preload("res://core/lab/fracture.gd")

const HV_MPA := Contact.HV_MPA
## Profundidad de la capa comprimida / espesor: donde se anula el perfil parabólico, ½·(1 − 1/√3) = 0,2113
## (Nielsen, Schneider & Kraus 2022: «aproximadamente el 21 % del espesor»).
const COMPRESSION_DEPTH_FRAC := 0.21132486540518713
## Compresión media en esa capa / compresión de la superficie: la media de ½(3ζ² − 1) entre ζ = 1/√3 y 1, normalizada
## por la de la superficie: (1/(3√3)) / (1 − 1/√3) = 0,4553 (cálculo sobre el mismo perfil).
const MEAN_COMPRESSION_FRAC := 0.45534180126147955
## Factor de intensidad de una grieta semicircular de superficie: K = Y·σ·√(πc), Y = 1,12·2/π (grieta en moneda con
## la corrección de superficie libre; valor de manual).
const SURFACE_CRACK_Y := 1.12 * 2.0 / PI
## Energía de fragmentación del templado: δ·U_D = 122,1 J/m² (Nielsen et al. 2022, ec. 4, R² = 0,93).
const FRAGMENT_ENERGY := 122.1
## Recuento de trozos en un cuadrado de 5 × 5 cm que exige la homologación de los templados de coche (CEPE R43):
## al menos 40 y como mucho 400 (450 si el espesor es ≤ 3,5 mm).
const R43_FRAGMENTS_MIN := 40
const R43_FRAGMENTS_MAX := 400
## Energía de la bola de 2260 g (82 mm) soltada desde 4 m en el ensayo de penetración del vidrio laminado (JIS R 3212;
## el de la CEPE R43 es equivalente), sobre probetas de 300 × 300 mm: no debe atravesarlas en 5 s.
## 2,26 kg · 9,81 m/s² · 4 m = 88,7 J. Es una cota inferior de la energía para atravesarlo con un objeto romo de 82 mm;
## con una punta afilada hará falta menos (sin medición).
const LAMINATED_BALL_J := 88.6824

## Ventanilla lateral de coche: vidrio templado de 4 mm. La hoja (pane) se usa con pane_break() igual que la ventana
## recocida, con la resistencia del templado.
const SIDE_WINDOW := {
	"id": "ventanilla", "name": "Ventanilla de coche", "hv": 550.0, "E": 72.0, "mohs": 5.5, "col": "#8FB8C8",
	"brittle": true, "tempered": true, "mu": 0.6, "W": 0.03,
	"pane": { "t": 4.0, "a": 250.0, "fgk": 120.0, "nu": 0.22 },
	"frac": {
		"Kc": 0.75, "nu": 0.22, "sigmaS": 100.0, "dolUm": 845.2994616207485, "vickersN": 0.18, "quality": "estimate",
		"source": "vidrio sodocálcico templado: K_c y umbral radial como el vidrio recocido del banco (Wiederhorn 1969; Mikowski et al. 2006); compresión superficial ESTIMADA en 100 MPa, dentro de los 80-150 MPa medidos en templados comerciales (Achintha 2020) y de los 81-144 MPa que corresponden, con la relación energía-trozo de Nielsen et al. (2022), a los 40-400 trozos por 5 × 5 cm de la CEPE R43 (la ASTM C1048 exige al menos 69 MPa); capa comprimida del 21 % del espesor (Nielsen et al. 2022)",
	},
	"quality": "estimate",
	"source": "espesor de 4 mm, el de las ventanillas de Europa y Japón (5 mm en EE. UU.; just-auto); ventanilla de ~50 cm (radio equivalente 250 mm): ESTIMACIÓN; resistencia a flexión 120 MPa (EN 12150-1, vía Saint-Gobain 2018); perfil de tensiones y trozos (Nielsen, Schneider & Kraus 2022); recuento de trozos (CEPE R43)",
	"fact": "Vidrio templado de ~4 mm: el temple deja las caras comprimidas (~100 MPa) y el centro en tracción. Aguanta más que el recocido, pero si una grieta atraviesa la capa comprimida (~0,8 mm) toda la energía guardada se libera y la ventanilla estalla en miles de trocitos romos (~90 por cada 5 × 5 cm). Un punzón duro y afilado lo consigue con mucha menos fuerza que un golpe.",
}
## Parabrisas: vidrio laminado 2,1 + 0,76 (PVB) + 2,1 mm. La hoja (pane) es el vidrio que flexa: las dos hojas de
## 2,1 mm trabajando juntas (4,2 mm, el PVB acopla a velocidad de golpe: ESTIMACIÓN) con la resistencia del recocido.
const WINDSCREEN := {
	"id": "parabrisas", "name": "Parabrisas", "hv": 550.0, "E": 72.0, "mohs": 5.5, "col": "#7FA9BF",
	"brittle": true, "laminated": { "plies": [2.1, 2.1], "pvbMm": 0.76, "penetrationJ": LAMINATED_BALL_J },
	"mu": 0.6, "W": 0.03,
	"pane": { "t": 4.2, "a": 400.0, "fgk": 45.0, "nu": 0.22 },
	"frac": {
		"Kc": 0.75, "nu": 0.22, "sigmaS": 0.0, "dolUm": 0.0, "vickersN": 0.18, "quality": "secondary",
		"source": "hojas de vidrio sodocálcico recocido: los mismos datos que el vidrio de ventana del banco (Wiederhorn 1969; Mikowski et al. 2006)",
	},
	"quality": "estimate",
	"source": "construcción 2,1 + 0,76 PVB + 2,1 mm de los fabricantes (Pilkington); parabrisas de ~80 cm (radio equivalente 400 mm) y las dos hojas acopladas por el PVB en un golpe: ESTIMACIÓN (a corta duración el laminado se comporta como el monolítico, Galić et al. 2022); resistencia del recocido 45 MPa (EN 572-1); ensayo de penetración con bola de 2260 g desde 4 m (JIS R 3212 / CEPE R43)",
	"fact": "Dos hojas de vidrio recocido pegadas a una lámina de plástico (PVB). Se agrieta con facilidad, en estrella y telaraña, pero la lámina sujeta los trozos: no cae ni corta. Atravesarlo exige romper también la lámina (la homologación pide que no lo pase una bola de 2,26 kg soltada desde 4 m).",
}
const TARGETS := [SIDE_WINDOW, WINDSCREEN]


## Profundidad de la capa comprimida (mm) de un templado de espesor t_mm.
static func compression_depth_mm(t_mm: float) -> float:
	return COMPRESSION_DEPTH_FRAC * t_mm


## Energía elástica por unidad de volumen del templado (J/m³): U_D = (1−ν)·σS²/(5E) (Nielsen et al. 2022, ec. 2),
## con σS en MPa y E en GPa: (1−ν)·(σS·10⁶)²/(5·E·10⁹) = 200·(1−ν)·σS²/E.
static func strain_energy_density(sigma_s: float, e_gpa: float, nu: float) -> float:
	return 200.0 * (1.0 - nu) * sigma_s * sigma_s / e_gpa


## Tamaño característico de los trozos (mm): δ = 122,1 J/m² / U_D (Nielsen et al. 2022, ec. 4).
static func fragment_size_mm(sigma_s: float, e_gpa: float, nu: float) -> float:
	var u := strain_energy_density(sigma_s, e_gpa, nu)
	return FRAGMENT_ENERGY * 1000.0 / u if u > 0.0 else INF


## Trozos en un cuadrado de 5 × 5 cm si el patrón es un panal hexagonal de lado entre núcleos δ (Nielsen et al.
## 2021: el patrón medio es un empaquetado hexagonal; cada celda mide (√3/2)·δ²).
static func fragments_per_25cm2(delta_mm: float) -> float:
	return 2500.0 / (0.8660254037844386 * delta_mm * delta_mm) if delta_mm > 0.0 else INF


## Carga (N) con la que una punta dura abre una grieta radial que atraviesa la capa comprimida: la grieta de Anstis
## (K = χ·P/c^(3/2), con el afilado de la punta, Fracture.radial_chi) tiene que vencer K_c más el cierre de la
## compresión media de la capa (K_res = Y·σ̄·√(πc)) a la profundidad d0 = 0,21·t. tan_a: tangente del semiángulo
## de la punta. MODELO (docs/fisica/pulido-materiales.md).
static func pierce_load(pane: Dictionary, frac: Dictionary, e_gpa: float, hv: float, tan_a: float) -> float:
	var d0: float = compression_depth_mm(pane.t) / 1000.0  # m
	var chi := Fracture.radial_chi(e_gpa, hv, tan_a)
	var sigma_mean: float = MEAN_COMPRESSION_FRAC * frac.sigmaS * 1.0e6  # Pa
	var k_res := SURFACE_CRACK_Y * sigma_mean * sqrt(PI * d0)
	return (d0 * sqrt(d0)) * (frac.Kc * 1.0e6 + k_res) / chi


## Ventanilla templada. peak_n: la fuerza de pico que llega a la hoja (N; la calcula compute() como en la ventana);
## bend_n: la fuerza que la parte por flexión (pane_break con fgk = 120 MPa); hard_tool: la punta es al menos tan
## dura como el vidrio (r ≥ 1); load_n: la carga en la punta; tan_a: tangente del semiángulo de la punta.
## { kind, shattered, cause: "flexión" | "grieta" | null, bendN, pierceN, compressionMm, fragmentMm, fragments25 }.
static func tempered_result(
	target: Dictionary, peak_n: float, bend_n: float, hard_tool: bool, load_n: float, tan_a: float
) -> Dictionary:
	var pane: Dictionary = target.pane
	var frac: Dictionary = target.frac
	var pierce := pierce_load(pane, frac, target.E, target.hv, tan_a)
	var cause: Variant = null
	if peak_n >= bend_n:
		cause = "flexión"
	elif hard_tool and load_n >= pierce:
		cause = "grieta"
	var delta := fragment_size_mm(frac.sigmaS, target.E, frac.nu)
	return {
		"kind": "templado", "shattered": cause != null, "cause": cause, "bendN": bend_n, "pierceN": pierce,
		"compressionMm": compression_depth_mm(pane.t), "fragmentMm": delta, "fragments25": fragments_per_25cm2(delta),
		"energyDensity": strain_energy_density(frac.sigmaS, target.E, frac.nu),
	}


## Parabrisas laminado. peak_n y bend_n como en el templado (con la resistencia del recocido); contact_cracks: la
## punta abre grietas de contacto (Fracture.evaluate(...).cracks); energy_j: la energía del golpe (0 si empuja).
## La homologación solo garantiza que NO lo atraviese una bola de 88,7 J: con más energía «puede atravesarlo»
## (penetrationRisk); el modelo no sabe cuánto más aguanta la lámina (sin medición con puntas).
## { kind, cracked, penetrationRisk, cause, bendN, penetrationJ }.
static func laminated_result(target: Dictionary, peak_n: float, bend_n: float, contact_cracks: bool, energy_j: float) -> Dictionary:
	var lam: Dictionary = target.laminated
	var cause: Variant = null
	if peak_n >= bend_n:
		cause = "flexión"
	elif contact_cracks:
		cause = "grieta"
	var pen_j: float = lam.penetrationJ
	return {
		"kind": "laminado", "cracked": cause != null, "penetrationRisk": cause != null and energy_j > pen_j,
		"cause": cause, "bendN": bend_n, "penetrationJ": pen_j,
	}
