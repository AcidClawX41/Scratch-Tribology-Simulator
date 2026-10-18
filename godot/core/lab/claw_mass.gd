## Tribología biológica · densidad de las garras experimentales y su efecto (modelo 2.0, unidad 4e). Funciones puras.
##
## Reforjar una garra en otro material (Data.INLAYS) cambia su dureza y su módulo (Physics.resolve_tool) y también su
## masa. ¿Importa esa masa? Se calcula en vez de suponerlo:
##   1. Densidad de cada material con fuente (DENSITY, kg/m³) y la de la queratina de la garra natural («none»).
##   2. Volumen de la garra: el cono del motor, con la base de radio 0,15 × alcance (Physics.MODEL.clawBase) y el alcance
##      de largo, V = π·r_b²·L/3; o, si se midió, un cono de base elíptica con el alto y el ancho de la base,
##      V = π·h·w·L/12 (la garra falciforme de Velociraptor). En el velocirraptor, el cono del motor es 5,8 veces el volumen
##      medido: si ni con él la masa importa, la conclusión es sólida.
##   3. Efecto en el golpe (energy_effect). La energía del golpe la ponen los músculos del animal (su trabajo W): una garra
##      más pesada, movida con el mismo trabajo, NO lleva más energía; va algo más lenta (v ∝ 1/√m) y con algo más de
##      impulso (p ∝ √m). Solo si la velocidad la impone otra cosa (el coche que se mueve contra el animal, una caída)
##      la masa añadida suma energía: ½·Δm·v². Con la masa de la garra frente a la del animal y a la masa eficaz del
##      golpe se ve cuánto: casi siempre un pequeño porcentaje (apenas cambia). Es educativo: manda la dureza, la forma
##      y la energía del animal, no el peso de la garra.
## Qué no predice: la inercia de la pata al barrer (nadie ha medido los segmentos de la pata de un dromeosáurido: se usa
## la masa eficaz del golpe de la ficha, `strike.m`), el equilibrio del animal con garras pesadas ni el desgaste.
## Unidades: densidad kg/m³ · volumen mm³ · masa kg · energía J · velocidad m/s.
## Uso: const ClawMass = preload("res://core/lab/claw_mass.gd").
extends RefCounted

## Radio de la base de una garra frente a su alcance: el del motor (Physics.MODEL.clawBase; un test comprueba que es el
## mismo). No se precarga physics.gd para que el motor pueda usar este módulo sin una precarga cíclica.
const CLAW_BASE := 0.15
## Diferencia relativa a partir de la cual el texto dice que el cambio «se nota». Es una elección de texto, no física.
const NOTICEABLE := 0.05

# ── Fuentes ──
const SRC_MASON := "Mason P (1963). Density and structure of alpha-keratin. Nature 197:179-180. doi:10.1038/197179a0 (valores de Fraser y MacRae a 25 °C: de 1,283 g/cm³ en el cuerno de vaca a 1,335 en la punta de las púas del equidna)"
const SRC_RSC_GOLD := "Royal Society of Chemistry, tabla periódica, «Gold»: 19,3 g/cm³ a 20 °C (de Haynes WM (ed.), CRC Handbook of Chemistry and Physics, 95.ª ed., 2014)"
const SRC_OUTOKUMPU := "Outokumpu (2013). Steel grades, properties and global standards, tabla de propiedades físicas: 1.4301 (304), 7,9 kg/dm³ y 200 GPa; 8,0 kg/dm³ en la ficha de thyssenkrupp Materials (ASTM A240)"
const SRC_METALCOR := "METALCOR, ficha técnica del titanio de grado 2 (3.7035, R50400): 4,51 g/cm³, 105 GPa, ≤ 150 HB"
const SRC_GC005 := "General Carbide, Grade Specifications: GC-005 (94,5 % de WC y 5,5 % de Co), 14,82-15,04 g/cm³ (la misma calidad con que se calcula la resistencia de las garras de tungsteno)"
const SRC_PILKINGTON := "Pilkington, Product Guide Technical Data: densidad del vidrio 158 lb/ft³ (2,53 g/cm³)"
const SRC_CRYSTAL_DIRECTIVE := "Directiva 69/493/CEE del Consejo, anexo I (vidrio de cristal): cristal al plomo con PbO ≥ 24 %, densidad ≥ 2,90; con PbO ≥ 30 %, ≥ 3,00"
const SRC_HOM := "Anthony JW, Bideaux RA, Bladh KW, Nichols MC (eds.), Handbook of Mineralogy, Mineralogical Society of America"
const SRC_NASSAU_1981 := "Nassau K (1981). Cubic zirconia: an update. Gems & Gemology 17:9-19, tabla 4. doi:10.5741/GEMS.17.1.9 (la sintética estabilizada: 5,60-6,00)"
const SRC_NASSAU_1997 := "Nassau K, McClure SF, Elen S, Shigley JE (1997). Synthetic moissanite: a new diamond substitute. Gems & Gemology 33:260-275 (densidad relativa 3,22)"
const SRC_COORSTEK := "CoorsTek, ficha técnica de la alúmina AD-995 (99,5 % de Al₂O₃): densidad 3,90 g/cm³"
const SRC_RUBY_CR := "el rubí es corindón con un poco de cromo (de 0,03 a 0,05 % de Cr₂O₃ en los láseres de Roditi y ~5 % en la mezcla de Verneuil para joyería): el cromo da el color y no cambia la densidad del corindón"

## Densidad (kg/m³) por id de Data.INLAYS y de los materiales nuevos de la 2.0 (Catalog.V2_INLAYS: el rubí y la alúmina de
## la reforja, unidades 5d y 5g); «none» es la garra natural de queratina. min y max: la banda.
const DENSITY := {
	"none": {
		"value": 1310.0, "min": 1283.0, "max": 1335.0, "quality": "estimate",
		"source": "caso medido más parecido: la queratina α de cuernos y púas (" + SRC_MASON + "). Suposición: la de las garras (con queratina β en aves y reptiles) es del mismo orden; no hemos encontrado su medición",
	},
	"oro": { "value": 19300.0, "min": 19300.0, "max": 19300.0, "quality": "secondary", "source": SRC_RSC_GOLD },
	"acero": { "value": 7900.0, "min": 7900.0, "max": 8000.0, "quality": "secondary", "source": SRC_OUTOKUMPU },
	"titanio": { "value": 4510.0, "min": 4510.0, "max": 4510.0, "quality": "secondary", "source": SRC_METALCOR },
	"tungsteno": { "value": 14930.0, "min": 14820.0, "max": 15040.0, "quality": "secondary", "source": SRC_GC005 },
	"vidrio": {
		"value": 2530.0, "min": 2530.0, "max": 3000.0, "quality": "estimate",
		"source": "caso medido más parecido: el vidrio sodocálcico de ventana (" + SRC_PILKINGTON + "), el mismo vidrio con que se calcula la resistencia de las garras de vidrio. Banda alta: el strass clásico es vidrio al plomo, como el cristal de la directiva (" + SRC_CRYSTAL_DIRECTIVE + ")",
	},
	"swarovski": {
		"value": 3000.0, "min": 2900.0, "max": 3000.0, "quality": "estimate",
		"source": "caso medido más parecido: el mínimo legal del cristal al plomo (" + SRC_CRYSTAL_DIRECTIVE + "). Suposición: el cristal clásico de Swarovski es cristal al plomo (el módulo del banco, 60 GPa, es el de un vidrio al plomo); desde 2012 lo hace sin plomo y no publica su densidad",
	},
	"hematites": { "value": 5260.0, "min": 5255.0, "max": 5260.0, "quality": "secondary", "source": SRC_HOM + ", «Hematite»: D(med.) 5,26, D(calc.) 5,255 (y VHN 1000-1100, la dureza del banco)" },
	"cuarzo": { "value": 2650.0, "min": 2650.0, "max": 2650.0, "quality": "secondary", "source": SRC_HOM + ", «Quartz»: D(med.) 2,65" },
	"circonita": { "value": 5800.0, "min": 5600.0, "max": 6000.0, "quality": "secondary", "source": SRC_NASSAU_1981 + ". El valor es el centro de la banda: depende del estabilizante" },
	"zafiro": { "value": 3980.0, "min": 3980.0, "max": 4100.0, "quality": "secondary", "source": SRC_HOM + ", «Corundum»: D(med.) 3,98-4,10, D(calc.) 3,997" },
	"moissanita": { "value": 3220.0, "min": 3220.0, "max": 3220.0, "quality": "primary", "source": SRC_NASSAU_1997 },
	"diamante": { "value": 3515.0, "min": 3511.0, "max": 3515.0, "quality": "secondary", "source": SRC_HOM + ", «Diamond»: D(med.) 3,511, D(calc.) 3,515" },
	# 2.0 · los materiales nuevos de la reforja (Catalog.V2_INLAYS). El rubí, la fila del zafiro (un test lo comprueba).
	"rubi": { "value": 3980.0, "min": 3980.0, "max": 4100.0, "quality": "secondary", "source": SRC_HOM + ", «Corundum»: D(med.) 3,98-4,10, D(calc.) 3,997; " + SRC_RUBY_CR },
	"alumina": { "value": 3900.0, "min": 3900.0, "max": 3900.0, "quality": "secondary", "source": SRC_COORSTEK },
}


# ════════ Densidad y masa ════════

## Id del material: una entrada de Data.INLAYS, su id, o null / «none» para la garra natural.
static func _id_of(inlay: Variant) -> String:
	if inlay is Dictionary:
		return String(inlay.get("id", "none"))
	return String(inlay) if inlay != null else "none"


## Densidad del material { value, min, max (kg/m³), quality, source }, o null si no hay dato.
static func density_of(inlay: Variant) -> Variant:
	return DENSITY.get(_id_of(inlay))


## Volumen (mm³) de la garra del motor: un cono de largo reach_mm con base de radio base_r_mm (por defecto, la del motor,
## 0,15 × alcance).
static func cone_volume_mm3(reach_mm: float, base_r_mm: float = -1.0) -> float:
	var rb := base_r_mm if base_r_mm > 0.0 else CLAW_BASE * reach_mm
	return PI * rb * rb * reach_mm / 3.0


## Volumen (mm³) de un cono de base elíptica de alto h y ancho w (mm) y largo reach_mm: π·h·w·L/12.
static func elliptic_cone_volume_mm3(reach_mm: float, height_mm: float, width_mm: float) -> float:
	return PI * height_mm * width_mm * reach_mm / 12.0


## Masa (kg) de una garra de volumen volume_mm3 en el material inlay (which: «value», «min» o «max» de su densidad). null
## si no hay densidad.
static func claw_mass_kg(inlay: Variant, volume_mm3: float, which: String = "value") -> Variant:
	var d: Variant = density_of(inlay)
	if d == null:
		return null
	return float(d[which]) * volume_mm3 * 1.0e-9


# ════════ Efecto en el golpe ════════

## Qué cambia al reforjar n_claws garras de volumen volume_mm3 en el material inlay, en un animal de animal_kg con una masa
## eficaz del golpe strike_m_kg a la velocidad strike_v_ms (la ficha: `strike`). Frente a las garras de queratina:
## { densityKgM3, clawKg, keratinKg, addedKg (todas las garras), bodyShare (añadida / animal), strikeShare (lo que pesa de
##   más una garra frente a la masa eficaz del golpe), sameWorkSpeed (v con el mismo trabajo muscular / v de siempre),
##   sameWorkEnergy (1: la misma energía), sameSpeedEnergy (energía con la misma velocidad / la de siempre), extraJ (lo
##   que suma a la misma velocidad), noticeable (algún cambio ≥ NOTICEABLE), quality, source }. null sin densidad.
static func energy_effect(
	inlay: Variant, volume_mm3: float, n_claws: int, animal_kg: float, strike_m_kg: float, strike_v_ms: float
) -> Variant:
	var d: Variant = density_of(inlay)
	var k: Variant = density_of("none")
	if d == null or k == null:
		return null
	var claw: float = float(d.value) * volume_mm3 * 1.0e-9
	var ker: float = float(k.value) * volume_mm3 * 1.0e-9
	var dm := claw - ker  # por garra (negativo si pesa menos que la queratina)
	var m_new := strike_m_kg + dm
	var share := dm / strike_m_kg if strike_m_kg > 0.0 else 0.0
	var same_work := sqrt(strike_m_kg / m_new) if m_new > 0.0 else 1.0
	var same_speed := m_new / strike_m_kg if strike_m_kg > 0.0 else 1.0
	var body := dm * float(n_claws) / animal_kg if animal_kg > 0.0 else 0.0
	return {
		"densityKgM3": d.value, "clawKg": claw, "keratinKg": ker, "addedKg": dm * float(n_claws), "bodyShare": body,
		"strikeShare": share, "sameWorkSpeed": same_work, "sameWorkEnergy": 1.0, "sameSpeedEnergy": same_speed,
		"extraJ": 0.5 * dm * strike_v_ms * strike_v_ms,
		"noticeable": absf(share) >= NOTICEABLE or absf(body) >= NOTICEABLE,
		"quality": d.quality, "source": d.source,
	}
