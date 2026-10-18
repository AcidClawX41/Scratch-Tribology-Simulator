## Tribología biológica · rotura de las garras reforjadas al golpear el metal (modelo 2.0, unidad 4d).
##
## Una garra «reforjada» en otro material (Data.INLAYS: acero, titanio, carburo de tungsteno, vidrio, cuarzo, zafiro,
## diamante…) conserva la forma de la garra y cambia su dureza y su módulo (Physics.resolve_tool). ¿Qué le pasa al golpear
## la chapa de un coche? Especificación, datos y fuentes: docs/fisica/coche-en-marcha.md, §11.
##
##   1. De frente no se rompe. Una punta más dura que el metal en el que se clava está en compresión triaxial y el metal
##      cede antes: el cono de diamante del Rockwell C (120°, radio de 0,2 mm) aguanta 1471 N contra acero templado en
##      cada ensayo (ISO 6508-2) y la bola de metal duro del Brinell, 29,42 kN (ISO 6506-1). Lo que rompe una punta dura
##      es la carga LATERAL: la fricción μ·F mientras la garra resbala por la chapa (el mismo impulso de fricción que frena
##      al animal en MovingCar.impact). Una garra más blanda que la chapa (el oro contra el acero) no se evalúa aquí: no la
##      corta y su punta cede, como la de queratina (el criterio del motor, r < 0,8).
##   2. La garra como viga en voladizo con esa carga lateral a la distancia x0 del vértice: σ(x) = 4·F·(x − x0)/(π·r(x)³)
##      en las secciones x > x0, con r(x) el radio de su sección: la punta esfero-cónica del motor (Contact.contact_radius)
##      hasta el radio de la base (Physics.resolve_tool: baseR = 0,15 × alcance). x0 es donde empuja la chapa: el centro de
##      la parte de la garra que está dentro del metal mientras lo indenta, y el borde del agujero cuando ya lo ha perforado
##      (MovingCar.load_point_mm). Con x0 = 0 es el modelo de mellado de la unidad 1f (Fracture.tip_chip_load); aquí se
##      añaden la sección de la base y el punto de carga.
##   3. Frágiles (metal duro, vidrio, cuarzo, circonita, zafiro, moissanita, diamante y, desde la 5g, el rubí y la alúmina
##      de la reforja, del catálogo 2.0): se rompen donde σ(x) llega a su
##      resistencia a flexión MEDIDA (módulo de rotura). La sección más cargada está cerca de la carga: primero se mella la
##      punta; con más fuerza se desprende un trozo más largo (en el cono, la sección x aguanta una fuerza ∝ x²) y, si la
##      base también llega, se parte la garra entera. El trozo que se da por perdido es todo el tramo que no aguanta esa
##      carga (cota alta: si se desprendiera a trozos, cada vez con la carga en el nuevo extremo, en un cono bastaría con
##      ~0,4 veces esa longitud).
##   4. Dúctiles (acero, titanio, oro): no estallan; se doblan cuando σ llega a su tensión de flujo, H/2,8 (Tabor 1951),
##      con la dureza del catálogo y la misma constante que usa el motor para los metales (Contact.CONTACT.tabor).
##   5. Sin resistencia medida (hematites): no se predice, y se dice.
## Qué no predice: el efecto de escala (una punta de décimas de milímetro aguanta más que la probeta de flexión: Weibull),
## la curvatura y la sección aplanada de una garra real, la compresión axial (que alivia la tracción), la fatiga, el golpe
## (la carga es cuasiestática, la de cada instante del camino) ni cómo se embota la punta después de mellarse.
## Unidades: fuerza N · longitudes mm · tensiones MPa · tenacidad MPa·√m. Funciones puras, deterministas y seguras para
## hilos (sin estado). Uso: const ClawFracture = preload("res://core/lab/claw_fracture.gd").
extends RefCounted

const Contact = preload("res://core/shared/contact.gd")
const Format = preload("res://core/shared/format.gd")
const Data = preload("res://core/lab/data.gd")
const CarFormat = preload("res://core/lab/car_format.gd")

const HV_MPA := Contact.HV_MPA
## Constante de Tabor del motor (H ≈ 2,8·σ): la tensión de flujo de un metal dúctil es su dureza entre 2,8.
const TABOR: float = Contact.CONTACT["tabor"]
## Pasos de la bisección de la longitud rota (sobre un tramo de milímetros: error ~1e-16 mm).
const BISECT_STEPS := 80

# ── Fuentes ──
const SRC_EN572 := "EN 572-1 (vidrio sodocálcico): resistencia característica a flexión del vidrio recocido, 45 MPa (la misma de la hoja de vidrio del banco); K_c 0,75 MPa·√m, el valor de referencia del vidrio sodocálcico (Wiederhorn 1969)"
const SRC_GC005 := "General Carbide (2018), Grade Specifications: GC-005, carburo de tungsteno con 5,5 % de Co submicrónico, 93,0-94,5 HRA (≈2000 HV, la del catálogo), rotura transversal media 445 000 psi = 3068 MPa (ASTM B406 / ISO 3327)"
const SRC_H6F := "Sandvik H6F (carburo de tungsteno con 6 % de Co, grano de 0,8 µm, 1775 HV30): 4000 MPa a flexión (ISO 3327) y 7050 MPa a compresión (ficha técnica de Sandvik)"
const SRC_WACHOWICZ := "Wachowicz J, Kruzel R, Bałaga Z, Ostrowska A, Dembiczak T (2023). Application of U-FAST technology in sintering of submicron WC-Co carbides. Materials 16:2450, doi:10.3390/ma16062450 (4 % de Co y grano de 0,8 µm: 2085 HV30 y K_IC 8,36 MPa·√m, Shetty)"
const SRC_CORNING := "Corning HPFS 7980 (sílice fundida), ficha técnica: módulo de rotura con la superficie desgastada, 52,4 MPa"
const SRC_IWASA := "Iwasa M, Ueno T, Bradt RC (1981). Fracture toughness of quartz and sapphire single crystals at room temperature. J. Soc. Mater. Sci. Japan 30:1001-1004, doi:10.2472/jsms.30.1001 (cuarzo 0,85-1,15 MPa·√m según el plano; zafiro 2,38-2,43)"
const SRC_ADAMS := "Adams JW, Ruh R, Mazdiyasni KS (1997). Young's modulus, flexural strength, and fracture of yttria-stabilized zirconia versus temperature. J. Am. Ceram. Soc. 80:903-908, doi:10.1111/j.1151-2916.1997.tb02920.x (circonia cúbica con 6,5 % mol de Y₂O₃ a 25 °C: ~300 MPa prensada en caliente y 150 MPa sinterizada)"
const SRC_PAJARES := "Pajares A, Guiberteau F, Domínguez-Rodríguez A, Heuer AH (1988). Microhardness and fracture toughness anisotropy in cubic zirconium oxide single crystals. J. Am. Ceram. Soc. 71:C332-C333, doi:10.1111/j.1151-2916.1988.tb05933.x (monocristal con 9,4 % mol de Y₂O₃: 1,5-1,9 MPa·√m con probeta entallada)"
const SRC_SAPPHIRE := "Saint-Gobain Crystals, Sapphire Products (ficha técnica, 2016-2018): resistencia a flexión de 1035 MPa paralela al eje c y 760 MPa perpendicular (25 °C); ≈2 GPa a compresión"
const SRC_QIAN := "Qian J, Daemen LL, Zhao Y (2005). Hardness and fracture toughness of moissanite. Diamond Relat. Mater. 14:1669-1672, doi:10.1016/j.diamond.2005.06.007 (6H-SiC monocristalino: K_IC 1,8 MPa·√m de 0,49 a 294 N)"
const SRC_HEXOLOY := "Saint-Gobain, Hexoloy SA (carburo de silicio sinterizado), ficha técnica: 380 MPa a flexión en cuatro puntos, 3900 MPa a compresión, K_IC 4,6 MPa·√m y módulo de Weibull 10"
const SRC_BALMER := "Balmer RS et al. (2009). Chemical vapour deposition synthetic diamond: materials, technology and applications. J. Phys.: Condens. Matter 21:364221, tabla 2, doi:10.1088/0953-8984/21/36/364221 (placas de diamante natural IIa pulidas, en voladizo: 2790 ± 1050 MPa con 14 placas y 2350 ± 400 MPa con 5)"
const SRC_FIELD := "Field JE (ed.) (1992). The Properties of Natural and Synthetic Diamond. Academic Press (resistencia teórica ~200 GPa y, con defectos de ~10 nm, ~10 GPa: la real la marcan los defectos de la superficie); K_c 3,4 ± 0,5 MPa·√m (Field & Freeman 1981, Philos. Mag. A 43:595-618, doi:10.1080/01418618108240397)"
const SRC_TABOR := "Tabor D (1951). The Hardness of Metals. Oxford, Clarendon Press: H ≈ c·σ con c ≈ 2,8-3 (la constante del motor, 2,8), con la dureza del catálogo del banco"
const SRC_INDENTERS := "ISO 6508-2 (Rockwell: cono de diamante de 120° y radio de 0,2 mm, 1471 N en HRC) e ISO 6506-1 (Brinell: bola de metal duro, hasta 29,42 kN)"
const SRC_COORSTEK := "CoorsTek, ficha técnica de la alúmina AD-995 (99,5 % de Al₂O₃): resistencia a flexión 379 MPa y tenacidad 4-5 MPa·√m (se toma el centro, 4,5)"
const SRC_RUBY_CR := "El rubí es corindón con un poco de cromo (de 0,03 a 0,05 % de Cr₂O₃ en los láseres de Roditi y ~5 % en la mezcla de Verneuil para joyería): el cromo da el color y la mecánica es la del zafiro"
## Unidad 4p: el cortante de la garra donde la empuja la chapa (shear_limit_n).
const SRC_SHEAR := "Cortante de una sección circular maciza: τ máx = 4V/(3A), en su diámetro neutro (Timoshenko SP, Gere JM (1997). Mechanics of Materials, 4.ª ed., PWS Publishing); un frágil se rompe cuando llega a su resistencia, porque en cortante puro la tensión principal es τ (criterio de la tensión normal máxima), y un dúctil fluye cuando llega a σ/√3 (von Mises), con la tensión de flujo de Tabor (Budynas RG, Nisbett JK (2015). Shigley's Mechanical Engineering Design, 10.ª ed., McGraw-Hill, cap. 5)"

## Frágiles con resistencia medida, por id de Data.INLAYS y de los materiales nuevos de la 2.0 (Catalog.V2_INLAYS: el rubí
## y la alúmina de la reforja, unidades 5d y 5g). value: resistencia a flexión (MPa) que se usa; min y max: la banda de las
## mediciones; kic: tenacidad (MPa·√m, informativa: dice por qué es frágil); quality y source.
## Una estimación («estimate») es siempre el caso medido más parecido, con la suposición escrita.
const BRITTLE := {
	"tungsteno": {
		"value": 3068.0, "min": 3068.0, "max": 4000.0, "kic": 8.36, "family": "metal duro",
		"quality": "secondary",
		"source": SRC_GC005 + ". Banda alta: " + SRC_H6F + ". Tenacidad: " + SRC_WACHOWICZ,
	},
	"vidrio": {
		"value": 45.0, "min": 45.0, "max": 45.0, "kic": 0.75, "family": "vidrio",
		"quality": "estimate",
		"source": "Caso medido más parecido: el vidrio recocido de la norma (" + SRC_EN572 + "). Suposición: el strass es un vidrio de silicato y su resistencia la marcan los defectos de la superficie, como en la hoja de la norma",
	},
	"swarovski": {
		"value": 45.0, "min": 45.0, "max": 45.0, "kic": 0.75, "family": "vidrio",
		"quality": "estimate",
		"source": "Caso medido más parecido: el vidrio recocido de la norma (" + SRC_EN572 + "). Suposición: el cristal de Swarovski es un vidrio de silicato sin medición publicada de su resistencia",
	},
	"cuarzo": {
		"value": 52.4, "min": 52.4, "max": 52.4, "kic": 1.0, "family": "cristal",
		"quality": "estimate",
		"source": "Caso medido más parecido: la sílice fundida, de la misma composición (" + SRC_CORNING + "). Suposición: sin medición a flexión del cuarzo monocristalino; su tenacidad es del mismo orden (" + SRC_IWASA + ")",
	},
	"circonita": {
		"value": 300.0, "min": 150.0, "max": 300.0, "kic": 1.9, "family": "cristal",
		"quality": "estimate",
		"source": "Caso medido más parecido: la circonia cúbica policristalina, del mismo compuesto (" + SRC_ADAMS + "). Suposición: el monocristal, sin poros, se parece a la prensada en caliente (el valor); la sinterizada, más porosa, es la banda baja. Tenacidad del monocristal: " + SRC_PAJARES,
	},
	"zafiro": {
		"value": 760.0, "min": 760.0, "max": 1035.0, "kic": 2.4, "family": "cristal",
		"quality": "secondary",
		"source": SRC_SAPPHIRE + ". Tenacidad: " + SRC_IWASA,
	},
	"moissanita": {
		"value": 380.0, "min": 148.7, "max": 380.0, "kic": 1.8, "family": "cristal",
		"quality": "estimate",
		"source": "Caso medido más parecido: el carburo de silicio sinterizado (" + SRC_HEXOLOY + "). Banda baja: la moissanita monocristalina es menos tenaz (" + SRC_QIAN + "); con los mismos defectos, σ ∝ K_IC (Griffith): 380 × 1,8/4,6 = 148,7 MPa",
	},
	"diamante": {
		"value": 2790.0, "min": 1740.0, "max": 3840.0, "kic": 3.4, "family": "cristal",
		"quality": "secondary",
		"source": SRC_BALMER + "; banda: la media ± una desviación. " + SRC_FIELD,
	},
	# 2.0 · los materiales nuevos de la reforja. El rubí, la fila del zafiro (un test lo comprueba).
	"rubi": {
		"value": 760.0, "min": 760.0, "max": 1035.0, "kic": 2.4, "family": "cristal",
		"quality": "secondary",
		"source": SRC_RUBY_CR + ". " + SRC_SAPPHIRE + ". Tenacidad: " + SRC_IWASA,
	},
	"alumina": {
		"value": 379.0, "min": 379.0, "max": 379.0, "kic": 4.5, "family": "ceramica",
		"quality": "secondary",
		"source": SRC_COORSTEK,
	},
}
## Dúctiles: fluyen y se doblan (Tabor, con la dureza del catálogo).
const DUCTILE := ["oro", "acero", "titanio"]
## Frágiles sin resistencia a flexión medida: la rotura no se predice (pregunta abierta).
const UNKNOWN := {
	"hematites": "no hay medición publicada de la resistencia a flexión de la hematites (Fe₂O₃): no se puede decir si se rompe",
}
## Nombre del material en los textos («la garra de …»). Solo texto.
const NOUNS := {
	"oro": "oro", "acero": "acero", "titanio": "titanio", "tungsteno": "carburo de tungsteno", "vidrio": "strass (vidrio)",
	"swarovski": "cristal Swarovski", "hematites": "hematites", "cuarzo": "cuarzo", "circonita": "circonita",
	"zafiro": "zafiro", "moissanita": "moissanita", "diamante": "diamante", "rubi": "rubí", "alumina": "alúmina",
}


# ════════ Datos ════════

## Id de un material (entrada de Data.INLAYS o de Catalog.INLAYS, o su id).
static func _id_of(inlay: Variant) -> String:
	if inlay is Dictionary:
		return String(inlay.get("id", "none"))
	return String(inlay) if inlay != null else "none"


## Material de la garra: la entrada de Data.INLAYS con ese id; si no está ahí y se pasa una entrada entera (los materiales
## nuevos de la 2.0 de Catalog.INLAYS, el rubí y la alúmina), esa entrada; y si solo se pasa el id de uno de ellos, una
## entrada mínima con su id y su nombre (son frágiles: su rotura no necesita la dureza, solo su fila de BRITTLE). null si no
## existe. Este módulo no precarga el catálogo: el catálogo lo precarga a él (a través de la reforja y del coche en
## marcha) y la precarga sería cíclica.
static func inlay_entry(inlay: Variant) -> Variant:
	var id := _id_of(inlay)
	var e: Variant = Data.find_by_id(Data.INLAYS, id)
	if e != null:
		return e
	if inlay is Dictionary and (inlay as Dictionary).has("hv"):
		return inlay
	if BRITTLE.has(id):
		return { "id": id, "name": String(NOUNS.get(id, id)) }
	return null


## ¿Es una garra reforjada? (false para la queratina, «none»).
static func is_reforged(inlay: Variant) -> bool:
	var e: Variant = inlay_entry(inlay)
	return e != null and e.id != "none"


## Comportamiento del material al romperse: «fragil», «ductil», «sin_datos» o «" (queratina o desconocido).
static func behavior(inlay: Variant) -> String:
	var id := _id_of(inlay)
	if BRITTLE.has(id):
		return "fragil"
	if DUCTILE.has(id):
		return "ductil"
	if UNKNOWN.has(id):
		return "sin_datos"
	return ""


## Resistencia del material: { value, min, max (MPa), kind («flexion» o «fluencia»), kic, family, quality, source } o
## null (queratina, desconocido o sin datos). En los dúctiles es la tensión de flujo de Tabor, H/2,8.
static func strength(inlay: Variant) -> Variant:
	var id := _id_of(inlay)
	if BRITTLE.has(id):
		var b: Dictionary = BRITTLE[id]
		return {
			"value": b.value, "min": b.min, "max": b.max, "kind": "flexion", "kic": b.kic, "family": b.family,
			"quality": b.quality, "source": b.source,
		}
	if DUCTILE.has(id):
		var e: Variant = inlay_entry(id)
		if e == null:
			return null
		var s: float = float(e.hv) * HV_MPA / TABOR
		return {
			"value": s, "min": s, "max": s, "kind": "fluencia", "kic": null, "family": "metal",
			"quality": "secondary", "source": SRC_TABOR,
		}
	return null


# ════════ La garra como viga en voladizo ════════

## Radio (mm) de la sección de la garra a la distancia x (mm) del vértice: la punta esfero-cónica del motor hasta el radio
## de la base (tip.amax).
static func section_radius(tip: Dictionary, x_mm: float) -> float:
	return minf(Contact.contact_radius(tip, x_mm), float(tip.get("amax", INF)))


## Tensión de flexión (MPa) por newton de carga lateral aplicada a x0_mm del vértice (0: en la punta), en la sección x:
## 4·(x − x0)/(π·r³) (1/mm²). Entre el vértice y la carga no hay flexión: 0.
static func bending_per_n(tip: Dictionary, x_mm: float, x0_mm: float = 0.0) -> float:
	var arm := x_mm - x0_mm
	if arm <= 0.0:
		return 0.0
	var r := section_radius(tip, x_mm)
	return (4.0 * arm) / (PI * r * r * r) if r > 0.0 else 0.0


## Distancia (mm) al vértice donde la sección llega al radio de la base (INF si no hay tope).
static func base_start_mm(tip: Dictionary) -> float:
	var amax := float(tip.get("amax", INF))
	return Contact.depth_for_radius(tip, amax) if is_finite(amax) else INF


## Sección más cargada del cono con la carga a x0 del vértice: en r = a_t + (x − h_t)·tan α, (x − x0)/r³ es máxima
## donde r = 3·(x − x0)·tan α, en x* = (a_t − h_t·tan α)/(2·tan α) + 1,5·x0 (con x0 = 0, la de la unidad 1f). Se busca
## desde el final de la esfera (h_t, como Fracture.tip_chip_load: antes, la carga se reparte en el contacto) o desde la
## carga, si está más lejos, hasta el comienzo de la base o el alcance.
static func _cone_peak_x(tip: Dictionary, reach_mm: float, x0_mm: float = 0.0) -> float:
	var t: float = tip.tanA
	var lo: float = maxf(maxf(float(tip.ht), 1e-6), x0_mm)
	var x_star := (float(tip.at) - float(tip.ht) * t) / (2.0 * t) + 1.5 * x0_mm if t > 0.0 else lo
	var hi := minf(base_start_mm(tip), reach_mm)
	return Contact.clamp_js(x_star, lo, maxf(hi, lo))


## Sección más cargada de toda la garra con la carga lateral a x0 del vértice: { factor (MPa/N), xMm }. En el cono la
## tensión sube y baja (máximo en x*); en la base, de radio constante, crece con x: el otro candidato es la base, en el
## alcance.
static func peak(tip: Dictionary, reach_mm: float, x0_mm: float = 0.0) -> Dictionary:
	var xc := _cone_peak_x(tip, reach_mm, x0_mm)
	var fc := bending_per_n(tip, xc, x0_mm)
	var xr := maxf(reach_mm, xc)
	var fr := bending_per_n(tip, xr, x0_mm)
	if fr > fc:
		return { "factor": fr, "xMm": xr }
	return { "factor": fc, "xMm": xc }


## Carga lateral (N) a x0 del vértice con la que la sección más cargada llega a la tensión s (MPa).
static func lateral_limit_n(tip: Dictionary, reach_mm: float, s_mpa: float, x0_mm: float = 0.0) -> float:
	var f: float = peak(tip, reach_mm, x0_mm).factor
	return s_mpa / f if f > 0.0 else INF


## Carga lateral (N) que aguanta a cortante la sección de la garra a x_mm del vértice, si toda la carga pasa por ella
## (unidad 4p; SRC_SHEAR): τ máx = 4V/(3A) en su sección circular llega a la resistencia a cortante del material, la de
## flexión en un frágil (en cortante puro, la tensión principal es τ) o la de flujo entre √3 en un dúctil (von Mises). El que
## llama elige la sección: claws_hold_n (moving_car.gd) toma la de la cara de fuera del metal, por donde ya ha pasado toda la
## carga de la chapa (con la presión repartida por el espesor, como en la regla de la chapa, en un cono el cortante es el
## mismo en toda la parte clavada). Es lo que manda cuando la garra está clavada hasta la base: el brazo hasta los dedos es
## casi nulo y la flexión no llega. s_mpa: una resistencia de strength() (value, min o max); kind: su kind («flexion» o
## «fluencia»).
static func shear_limit_n(tip: Dictionary, x_mm: float, s_mpa: float, kind: String) -> float:
	var r := section_radius(tip, x_mm)
	if r <= 0.0 or s_mpa <= 0.0:
		return 0.0
	var tau := s_mpa if kind == "flexion" else s_mpa / sqrt(3.0)
	return tau * 3.0 * PI * r * r / 4.0


## Trozo (mm, desde el vértice) donde la tensión con la carga lateral f_n a x0 del vértice pasa de s: la sección más lejana
## del vértice que llega. Si llega la base (la sección del alcance), es la garra entera (reach_mm); si no, se busca en el
## tramo del cono en el que la tensión baja (bisección). 0 si no llega ninguna.
static func broken_length_mm(tip: Dictionary, reach_mm: float, s_mpa: float, f_n: float, x0_mm: float = 0.0) -> float:
	if f_n <= 0.0 or s_mpa <= 0.0:
		return 0.0
	var xc := _cone_peak_x(tip, reach_mm, x0_mm)
	if bending_per_n(tip, xc, x0_mm) * f_n < s_mpa and bending_per_n(tip, reach_mm, x0_mm) * f_n < s_mpa:
		return 0.0
	# la base, de radio constante, tiene su máximo en el alcance; si llega, cualquier sección desde el mínimo también
	var x_low := minf(base_start_mm(tip), reach_mm)
	if bending_per_n(tip, reach_mm, x0_mm) * f_n >= s_mpa or bending_per_n(tip, x_low, x0_mm) * f_n >= s_mpa:
		return reach_mm
	var lo := xc
	var hi := x_low
	for i in BISECT_STEPS:
		var mid := 0.5 * (lo + hi)
		if bending_per_n(tip, mid, x0_mm) * f_n >= s_mpa:
			lo = mid
		else:
			hi = mid
	return lo


# ════════ El golpe ════════

## ¿Se rompe (o se dobla) la garra reforjada? inlay: material (Data.INLAYS o su id); tip: su geometría (Contact.tip_geometry
## con amax = el radio de la base); reach_mm: su alcance (longitud útil); normal_n: fuerza normal sobre ESA garra en el
## instante más cargado (N); mu: fricción con la chapa mientras resbala; load_x_mm: dónde empuja la chapa, en mm desde el
## vértice (0: en la punta). Para una garra más dura que el metal que golpea (MovingCar.can_cut_body): una más blanda cede
## por la punta y no se evalúa. null si la garra es de queratina («none») o el material no existe.
## { ok, material, name, behavior («fragil» | «ductil» | «sin_datos»), strengthMPa, strengthMinMPa, strengthMaxMPa,
##   strengthKind («flexion» | «fluencia»), kic, normalN, mu, lateralN, loadXmm, limitN, limitMinN, limitMaxN (la carga
##   lateral en loadXmm que la rompe con la resistencia central, la mínima y la máxima), stressMPa (la de la sección más
##   cargada), peakXmm, breaks (frágil que se rompe), bends (dúctil que se dobla), breaksLo, breaksHi (con la resistencia
##   mínima y la máxima), mode («intacta» | «mella» | «parte» | «dobla» | «sin_datos»), brokenMm, atBase, verdict, vsub,
##   reason, quality, source }.
static func evaluate(
	inlay: Variant, tip: Dictionary, reach_mm: float, normal_n: float, mu: float, load_x_mm: float = 0.0
) -> Variant:
	var e: Variant = inlay_entry(inlay)
	if e == null or e.id == "none":
		return null
	var id: String = e.id
	var lateral := maxf(mu, 0.0) * maxf(normal_n, 0.0)
	var x0 := maxf(load_x_mm, 0.0)
	var out := {
		"ok": true, "material": id, "name": String(NOUNS.get(id, String(e.name).to_lower())), "behavior": behavior(id),
		"normalN": maxf(normal_n, 0.0), "mu": maxf(mu, 0.0), "lateralN": lateral, "loadXmm": x0, "strengthMPa": null,
		"strengthMinMPa": null, "strengthMaxMPa": null, "strengthKind": null, "kic": null, "limitN": null,
		"limitMinN": null, "limitMaxN": null, "stressMPa": null, "peakXmm": null, "breaks": false, "bends": false,
		"breaksLo": false, "breaksHi": false, "mode": "sin_datos", "brokenMm": 0.0, "atBase": false, "reason": "",
		"verdict": "", "vsub": "", "quality": null, "source": null,
	}
	var s: Variant = strength(id)
	if s == null:
		var why := String(UNKNOWN.get(id, "sin datos de rotura de este material"))
		out["reason"] = why
		out["verdict"] = "SIN DATOS DE ROTURA"
		out["vsub"] = why
		return out
	var pk := peak(tip, reach_mm, x0)
	var f: float = pk.factor
	var sv: float = s.value
	var smin: float = s.min
	var smax: float = s.max
	var limit := sv / f if f > 0.0 else INF
	var fails := lateral > 0.0 and lateral >= limit
	var brittle: bool = s.kind == "flexion"
	var broken := broken_length_mm(tip, reach_mm, sv, lateral, x0) if fails else 0.0
	var at_base := fails and broken >= reach_mm
	out.merge({
		"strengthMPa": sv, "strengthMinMPa": smin, "strengthMaxMPa": smax, "strengthKind": s.kind, "kic": s.kic,
		"limitN": limit, "limitMinN": smin / f if f > 0.0 else INF, "limitMaxN": smax / f if f > 0.0 else INF,
		"stressMPa": lateral * f, "peakXmm": pk.xMm,
		"breaks": brittle and fails, "bends": not brittle and fails,
		# banda: con los datos más desfavorables (la resistencia mínima) y con los más favorables (la máxima)
		"breaksLo": lateral > 0.0 and lateral * f >= smin, "breaksHi": lateral > 0.0 and lateral * f >= smax,
		"brokenMm": broken, "atBase": at_base, "quality": s.quality, "source": s.source,
	}, true)
	if not fails:
		out["mode"] = "intacta"
	elif not brittle:
		out["mode"] = "dobla"
	else:
		out["mode"] = "parte" if at_base else "mella"
	var v := verdict_of(out)
	out["verdict"] = v.verdict
	out["vsub"] = v.vsub
	return out


## Veredicto de la garra: { verdict, vsub }.
static func verdict_of(r: Dictionary) -> Dictionary:
	var what := "la garra de %s" % String(r.name)
	var lat := _fmt_n(r.lateralN)
	match String(r.mode):
		"sin_datos":
			return { "verdict": "SIN DATOS DE ROTURA", "vsub": r.reason }
		"intacta":
			var would := "mellaría" if r.strengthKind == "flexion" else "doblaría"
			if float(r.lateralN) <= 0.0:
				return {
					"verdict": "LA GARRA AGUANTA",
					"vsub": "golpe de frente, sin nada que resbalar: sin carga lateral, una punta dura no se rompe (%s se %s desde ~%s de lado)" % [
						what, would, _fmt_n(r.limitN)],
				}
			return {
				"verdict": "LA GARRA AGUANTA",
				"vsub": "~%s de lado; %s se %s desde ~%s" % [lat, what, would, _fmt_n(r.limitN)],
			}
		"dobla":
			var where := "por la base" if r.atBase else "los últimos ~%s" % Format.fmt_len(float(r.brokenMm) * 1000.0)
			return {
				"verdict": "SE DOBLA LA GARRA",
				"vsub": "~%s de lado contra ~%s: %s no estalla, fluye a ~%s MPa y se dobla %s" % [
					lat, _fmt_n(r.limitN), what, Format.fmt_p(r.strengthMPa), where],
			}
		"parte":
			return {
				"verdict": "SE PARTE LA GARRA",
				"vsub": "~%s de lado contra ~%s que aguanta la punta (%s MPa a flexión): %s se parte por la base" % [
					lat, _fmt_n(r.limitN), Format.fmt_p(r.strengthMPa), what],
			}
	return {
		"verdict": "SE MELLA LA PUNTA",
		"vsub": "~%s de lado contra ~%s que aguanta (%s MPa a flexión): a %s se le desprenden ~%s de la punta" % [
			lat, _fmt_n(r.limitN), Format.fmt_p(r.strengthMPa), what, Format.fmt_len(float(r.brokenMm) * 1000.0)],
	}


## Fuerza legible: N hasta 10 kN; después kN con un decimal; por debajo de 0,05 N (la punta afilada de una garra
## reforjada, unidad 4i-B2), en milinewtons y menos, no «0.0 N». El formato vive en core/lab/car_format.gd (unidad 4j).
static func _fmt_n(f: float) -> String:
	return CarFormat.fmt_n_small(f)
