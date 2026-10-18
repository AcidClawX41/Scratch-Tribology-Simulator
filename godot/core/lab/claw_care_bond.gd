## Tribología biológica · cetrería: colocar a mano la pieza que sale de la reforja (unidad 5o, petición 43). Sin nodos y
## determinista: un objeto por pieza, que ClawCareState lleva en la garra a la que va.
##
## La pieza llega sin pegar y la coloca el usuario, paso a paso; nada se hace solo:
##   1. preparar la garra: limpiar y desengrasar (alcohol o clorhexidina), secar (el alcohol se evapora; la clorhexidina,
##      que es agua, con la gasa) y lijar un poco la queratina donde va a pegar (la rugosidad la deja la lija de verdad,
##      ClawCare.file); saltarse un paso deja la unión más débil, con su factor (CareData.BOND_PREP);
##   2. pegar según el método:
##      - «adhesivo»: una pieza rígida (la funda de la reforja o el bloque de la garra rota) con cianoacrilato, epoxi,
##        metacrilato o la masilla de epoxi con acero; las jeringas dobles se purgan antes (CareData.BOND_PURGE). Se coloca
##        (alineada con el eje de la garra), se sujeta quieta hasta que fija (con la mano o con una venda) y cura con su
##        reloj (CareData.BOND_TIMES: de la fijación a la plena resistencia, lineal en el logaritmo del tiempo);
##      - «acrilico»: el acrílico dental autopolimerizable, polvo y líquido en su proporción, en la fase de masa y en capas;
##        cada capa fragua con su reloj y desprende el calor de la polimerización (power_w: entra en el modelo térmico de
##        la garra con ClawCare.exotherm);
##      - «resina»: la resina compuesta fotopolimerizable, en capas que se curan con la lámpara: la dosis es la irradiancia
##        por el tiempo y la profundidad de curado, Cd = Dp·ln(E/Ec) (CareData.CURE_DEPTH, LAMPS);
##   3. quitar lo que rebosa: en fresco con la espátula; ya duro, con la lima (lo que arranca, el modelo de la 5l);
##   4. probar la unión: un tirón suave de lado contra lo que aguanta (ClawForge.bond_capacity por los factores de la
##      preparación, la humedad, la holgura y lo curado que esté); si no aguanta, se despega y dice por qué.
## La física de los adhesivos (el cortante, la holgura y la queratina que rompe antes) es la de la reforja, sin cambiarla.
## Unidades: tiempo s (el del ensayo, ClawCare.time_s) · longitud mm · área mm² · volumen mm³ · fuerza N · tensión MPa ·
## dosis J/cm² · irradiancia mW/cm² · calor J · potencia W.
## Uso: var b := ClawCareBond.new(piece); b.clean("alcohol", t); b.dry(t)…; b.check("fijada", t); b.view(t, humidity, force)
extends RefCounted

const CareData = preload("res://core/lab/claw_care_data.gd")
const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const ClawForge = preload("res://core/lab/claw_forge.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")

const METHODS := ["adhesivo", "acrilico", "resina"]
const METHOD_NAMES := { "adhesivo": "Pegar con adhesivo", "acrilico": "Acrílico dental", "resina": "Resina con la lámpara" }
const ADHESIVE_IDS := ["cianoacrilato", "epoxi", "metacrilato", "masilla"]
const CLEANERS := ["alcohol", "clorhexidina"]
## La parte de la garra donde está la unión (mm a cada lado de ella): ahí, limar quita lo que rebosa y el escalón.
const JOINT_ZONE_MM := 2.0
## Lo curado que tiene que estar para que una prueba no diga «sin curar» (fracción de la plena resistencia): elección de la
## interfaz, para el aviso; lo que decide si aguanta es la capacidad.
const CURED_WORDS := 0.5

## La pieza: { kind (funda | bloque | protesis), material, name, fiction, note, source, gapMm, areaMm2, jointMm (mm desde la
## base), stumpRadiusMm, wallMm, needMm (lo que hay que construir con capas), methods, fs (los ajustes de la reforja) }.
var piece: Dictionary = {}
var method := ""
var adhesive := ""
## Preparar: con qué se limpió («» sin limpiar) y cuándo; si queda agua de la clorhexidina; la rugosidad de la zona (µm).
var cleaner := ""
var clean_t := -1.0
var wet := false
var ra_um := 0.0
## La jeringa doble purgada (para el adhesivo elegido).
var purged := false
## El adhesivo puesto (s del ensayo; −1 sin poner) y si estaba purgado.
var applied_t := -1.0
var applied_purged := false
## La pieza en la mano, su inclinación (grados frente al eje de la garra) y dónde se apunta (mm del centro del muñón); si
## está sobre el muñón (aim_docked: lo dice la escena; sin escena, sí).
var held := false
var tilt_deg := 0.0
var aim_mm := 0.0
var aim_docked := true
## Colocada: { t, offset, tilt }; sujeta: con la mano (holding, desde hold_t) o con la venda (wrapped, desde wrap_t).
var placed: Dictionary = {}
var holding := false
var hold_t := -1.0
var moved_mm := 0.0
var wrapped := false
var wrap_t := -1.0
## Fijada (s del ensayo en que llegó a la fijación; −1 si no) y el fallo que obliga a quitarla y empezar de nuevo.
var fixed_t := -1.0
var failure := ""
## Lo que rebosa (mm³) y el escalón de la funda (mm) que queda a la vista.
var flash_mm3 := 0.0
var step_mm := 0.0
## El acrílico: la mezcla en el vaso ({ t, ratio } o {}) y las capas [{ t_mix, t_apply, h, top, q, ratio }].
var mix: Dictionary = {}
var layers: Array = []
var built_mm := 0.0
## La resina: la lámpara elegida, la distancia (mm), el intervalo (s), los ojos tapados (filtro y capucha), la lámpara
## encendida (desde lamp_t, hasta lamp_end) y las capas [{ h, dose, cd, cured }].
var lamp := "azul"
var lamp_mm := 1.0
var lamp_s := 20.0
var eyes_covered := false
var lamp_on := false
var lamp_t := -1.0
var lamp_end := -1.0
var resin: Array = []
## La última prueba de la unión ({} sin probar) y el último aviso.
var test: Dictionary = {}
var notice := ""
## Número que cambia con cada cambio (la vista repinta solo si cambia).
var serial := 0


func _init(p: Dictionary = {}) -> void:
	piece = p.duplicate(true)
	ra_um = float(CareData.SURFACE.natural_ra_um.value)
	tilt_deg = float(CareData.BOND_ALIGN.start_tilt_deg)
	var ms: Array = piece.get("methods", ["adhesivo"])
	method = String(ms[0]) if not ms.is_empty() else "adhesivo"
	adhesive = "metacrilato" if String(piece.get("kind", "")) == "bloque" else "epoxi"


# ════════════════════════════════ La pieza ════════════════════════════════

## El material de la pieza en palabras para los textos («una funda de acero»): el catálogo del banco los nombra por su pieza de
## la 1.x («Tachuela de acero»). Sin entrada, el nombre del catálogo en minúsculas.
const MATERIAL_WORDS := {
	"acero": "acero", "oro": "oro", "titanio": "titanio", "tungsteno": "metal duro", "zafiro": "zafiro", "rubi": "rubí",
	"alumina": "alúmina", "diamante": "diamante", "vidrio": "vidrio", "cuarzo": "cuarzo", "circonita": "circonita",
	"moissanita": "moissanita", "hematites": "hematites", "cristal": "cristal", "acrilico": "acrílico dental", "resina": "resina",
}


static func material_words(mid: String) -> String:
	if MATERIAL_WORDS.has(mid):
		return String(MATERIAL_WORDS[mid])
	var e: Variant = ForgeData.inlay_entry(mid)
	return String(e.name).to_lower() if e != null else mid


## La pieza que llega de la reforja (fs = ClawForge.care_setup: con block, la garra rota; sin él, la funda entera), con lo
## que falta calculado con las funciones de la reforja: el área pegada y la holgura. stump_r_mm: el radio de lo que queda de
## la garra donde se rompió (ClawCare.radius_at); claw y shape: la ficha de la garra y la forma de su dedo
## (CareData.claw_entry, claw_shape).
## Desde la 5m, fs.piece trae la pieza terminada del laboratorio (ClawForge._piece_for_care): la forma elegida (lo que cubre,
## coverMm, y la pared que le queda, wallLeftMm), la superficie que se pega (bondAreaMm2) y la holgura de la prueba del ajuste
## (gapMm: la de diseño más lo que cambió una colada sin compensar; negativa, no entra). Sin ella, la funda de serie
## (ForgeData.SHEATH) con la holgura de fs.gap_mm o, si no la trae, la ideal del epoxi (ForgeData.ADHESIVES).
## Con la garra rota: el bloque en bruto (sin tallar) se pega por la cara de la rotura; el acrílico de la prótesis de verdad
## se construye sobre el muñón; y una prótesis rígida ya tallada y pulida en el laboratorio se pega como una funda sobre lo
## que queda (rehace macizo lo que falta: ClawForge.sheath_geometry con gone_mm).
static func piece_from(fs: Dictionary, claw: Dictionary, shape: Dictionary, stump_r_mm: float) -> Dictionary:
	var lab: Dictionary = (fs.get("piece") as Dictionary) if fs.get("piece") is Dictionary else {}
	var gap := float(lab.get("gapMm", fs.get("gap_mm", ForgeData.ADHESIVES.epoxi.gap_ideal)))
	var reach := float(claw.get("reach", 0.0)) * float(shape.get("lengthRatio", 1.0))
	var blk: Variant = fs.get("block", null)
	var carved := bool(lab.get("carved", false)) and bool(lab.get("ok", false))
	if blk is Dictionary and not carved:
		var b: Dictionary = blk
		var mid := String(b.get("material", ""))
		var pros := ForgeData.PROSTHESIS.has(mid)
		var e: Variant = ForgeData.inlay_entry(mid)
		var stump := float(b.get("stump_mm", 0.0))
		var wall := float(b.get("wall_mm", ForgeData.SHEATH.wall_mm))
		return {
			"kind": "protesis" if pros else "bloque", "label": "prótesis de verdad" if pros else "bloque en bruto", "broken": true,
			"material": mid, "name": String(e.name) if e != null else mid,
			"fiction": bool(b.get("fiction", not pros)), "note": String(b.get("note", "")), "source": String(b.get("source", "")),
			# el bloque se pega por la cara de la rotura (como lo dibuja ClawCare: un cilindro desde el muñón)
			"gapMm": 0.0 if pros else gap, "areaMm2": PI * stump_r_mm * stump_r_mm, "jointMm": stump, "stumpRadiusMm": stump_r_mm,
			"wallMm": wall, "needMm": maxf(reach, stump) + wall - stump,
			"methods": ["acrilico", "resina"] if pros else ["adhesivo"], "fs": fs.duplicate(true), "lab": lab.duplicate(true),
		}
	# una pieza rígida terminada: la funda de la garra entera o la prótesis tallada sobre lo que queda de la rota
	var broken := blk is Dictionary
	var iid := String((blk as Dictionary).get("material", "")) if broken else String(fs.get("inlay", "none"))
	var ie: Variant = ForgeData.inlay_entry(iid)
	var nm := material_words(iid)
	var cover := float(lab.get("coverMm", reach * float(ForgeData.SHEATH.cover_frac)))
	var wall_s := float(lab.get("wallLeftMm", lab.get("wallMm", ForgeData.SHEATH.wall_mm)))
	var gone := maxf(reach - float((blk as Dictionary).get("stump_mm", reach)), 0.0) if broken else 0.0
	var area := float(lab.get("bondAreaMm2", -1.0))
	if area < 0.0:
		area = float(ClawForge.sheath_geometry(claw, cover, wall_s, gone, shape).innerAreaMm2)
	var note := "FICCIÓN: una funda de %s pegada a una garra no se hace de verdad. Lo real que se le parece: las fundas de vinilo que se pegan a las uñas de los gatos y las herraduras pegadas al casco; una funda dura sobre una garra viva haría palanca en la queratina y se caería al crecer." % nm
	if broken:
		note = "FICCIÓN: una prótesis de %s tallada aparte y pegada sobre lo que queda de una garra rota no se hace de verdad en un animal; lo real es el acrílico dental o la resina sobre el muñón, como en el pico de las aves. Una prótesis dura haría palanca en la queratina y se caería al crecer." % nm
	return {
		"kind": "funda", "label": "prótesis tallada" if broken else "funda", "broken": broken, "material": iid,
		"name": String(ie.name) if ie != null else iid, "fiction": true, "note": note,
		"source": ForgeData.SRC_FERREIRA + ("; " + ForgeData.SRC_SAMOUR_REPAIR if broken else ""), "gapMm": gap, "areaMm2": area,
		"jointMm": maxf(reach - cover, 0.0), "stumpRadiusMm": 0.0, "wallMm": wall_s, "needMm": 0.0,
		"methods": ["adhesivo"], "fs": fs.duplicate(true), "lab": lab.duplicate(true),
	}


## Los datos de un adhesivo: los de la reforja (ForgeData.ADHESIVES) o la masilla (CareData.PUTTY).
static func adhesive_data(id: String) -> Dictionary:
	if id == "masilla":
		return CareData.PUTTY
	return ForgeData.ADHESIVES.get(id, {})


## Los tiempos de un adhesivo (CareData.BOND_TIMES o PUTTY_TIMES).
static func adhesive_times(id: String) -> Dictionary:
	if id == "masilla":
		return CareData.PUTTY_TIMES
	return CareData.BOND_TIMES.get(id, {})


## Lo que aguanta una unión pegada sin más factores (ClawForge.bond_capacity; la masilla, con la misma regla).
static func base_capacity(id: String, gap_mm: float, area_mm2: float, humidity: String) -> Dictionary:
	var g := fit_gap(id, gap_mm)
	if id != "masilla":
		return ClawForge.bond_capacity(id, g, area_mm2, humidity)
	gap_mm = g
	var a := CareData.PUTTY
	var cures := gap_mm >= 0.0 and gap_mm <= float(a.gap_max)
	var wetx := humidity in ["humeda", "empapada"]
	var t_adh := float(a.tau) * (float(a.wet) if wetx else 1.0) if cures else 0.0
	var t_ker := ClawForge.keratin_shear_mpa(humidity)
	var tau := minf(t_adh, t_ker)
	var by := "holgura" if not cures else ("queratina" if t_ker < t_adh else "adhesivo")
	return { "cures": cures, "tauMPa": tau, "adhesiveMPa": t_adh, "keratinMPa": t_ker, "capacityN": tau * maxf(area_mm2, 0.0), "limitedBy": by }


# ════════════════════════════════ Física pura ════════════════════════════════

## La holgura que se compara con la que llena un adhesivo: la de la prueba del ajuste del laboratorio llega con decimales de coma
## flotante (0,15000000000000002 mm con 0,15 de diseño); como la prueba del ajuste (ClawForge.fit), se tolera 1e-9 mm.
static func fit_gap(id: String, gap_mm: float) -> float:
	var a := adhesive_data(id)
	if not a.is_empty() and gap_mm > float(a.gap_max) and gap_mm <= float(a.gap_max) + 1e-9:
		return float(a.gap_max)
	return gap_mm


## ¿Llena ese adhesivo esa holgura? (con la tolerancia de fit_gap)
static func fills(id: String, gap_mm: float) -> bool:
	var a := adhesive_data(id)
	return not a.is_empty() and gap_mm >= 0.0 and fit_gap(id, gap_mm) <= float(a.gap_max)


## Lo que conserva cada adhesivo sobre la queratina según su rugosidad (µm): de la lisa (BOND_PREP.smooth) a la rugosa (1),
## lineal en el logaritmo de Ra entre ra_smooth_um y ra_rough_um. Nunca baja al lijar más.
static func rough_factor(adh: String, ra: float) -> float:
	var p := CareData.BOND_PREP
	var lo := float((p.smooth as Dictionary).get(adh if adh != "masilla" else "epoxi", 1.0))
	var a := float(p.ra_smooth_um)
	var b := float(p.ra_rough_um)
	var x := clampf((V8.js_log(maxf(ra, 1e-6)) - V8.js_log(a)) / (V8.js_log(b) - V8.js_log(a)), 0.0, 1.0)
	return lo + (1.0 - lo) * x


## Lo curado que está un adhesivo t segundos después de colocar la pieza (fracción de su cortante pleno): lineal hasta la
## fijación (0,1 N/mm²), lineal en el logaritmo del tiempo de ahí a la plena resistencia (CareData.BOND_TIMES), 1 después.
## Nunca baja con el tiempo.
static func cure_fraction(adh: String, t: float) -> float:
	var tm := adhesive_times(adh)
	var a := adhesive_data(adh)
	if tm.is_empty() or a.is_empty() or t <= 0.0:
		return 0.0
	var f_fix := minf(0.1 / float(a.tau), 1.0)
	var fix := float(tm.fix_s)
	var full := float(tm.full_s)
	if t <= fix:
		return f_fix * t / fix
	if t >= full:
		return 1.0
	var u := (V8.js_log(t) - V8.js_log(fix)) / (V8.js_log(full) - V8.js_log(fix))
	return f_fix * V8.js_pow(1.0 / f_fix, u)


## La parte del calor de una mezcla de acrílico que ya ha salido x segundos después de mezclarla: un triángulo de 0 al
## fraguado con el pico en peak_frac (CareData.ACRYLIC_HEAT).
static func acrylic_heat_cdf(x: float) -> float:
	var set_s := float(CareData.ACRYLIC_MIX.set_s)
	var u := clampf(x / set_s, 0.0, 1.0)
	var c := float(CareData.ACRYLIC_HEAT.peak_frac)
	if u <= c:
		return u * u / c
	return 1.0 - (1.0 - u) * (1.0 - u) / (1.0 - c)


## El calor (J) que desprende una capa de acrílico de h mm sobre una sección de radio r mm, con la proporción polvo:líquido
## ratio: masa × fracción de monómero × ΔH/M × lo que reacciona (CareData.ACRYLIC_HEAT). Más gruesa, nunca menos.
static func acrylic_heat_j(h_mm: float, r_mm: float, ratio: float) -> float:
	var hh := CareData.ACRYLIC_HEAT
	var vol_m3 := PI * r_mm * r_mm * maxf(h_mm, 0.0) * 1.0e-9
	var mass := float(hh.density) * vol_m3
	var w_m := 1.0 / (1.0 + maxf(ratio, 0.1))
	return mass * w_m * float(hh.dh_j_mol) / float(hh.molar_kg) * (1.0 - float(hh.residual))


## Lo que aguanta el acrílico con una proporción que no es la de la ficha (CareData.ACRYLIC_RATIO).
static func ratio_factor(ratio: float) -> float:
	var off := absf(ratio - float(CareData.ACRYLIC_MIX.ratio_w)) / 0.5
	return V8.js_pow(float(CareData.ACRYLIC_RATIO.off_ratio), off)


## La irradiancia que llega a la capa (mW/cm²) con la lámpara a d_mm: la de su punta por (R/(R + d·tan θ))² y por la parte
## de su luz que cura el composite (CareData.LAMPS, CURE_DEPTH). Nunca crece al alejarla.
static func irradiance_at(lamp_id: String, d_mm: float) -> float:
	var l: Dictionary = CareData.LAMPS.get(lamp_id, CareData.LAMPS.azul)
	var c := CareData.CURE_DEPTH
	var r := float(c.tip_r_mm)
	var spread := r + maxf(d_mm, 0.0) * V8.js_tan(float(c.spread_deg) * PI / 180.0)
	return float(l.irradiance) * float(l.eff) * (r / spread) * (r / spread)


## La profundidad de curado (mm) con una dosis E (J/cm²): Cd = Dp·ln(E/Ec), con Ec de la ficha (2,5 mm con 8 J/cm²). 0 sin
## dosis suficiente. Más dosis, nunca menos.
static func cure_depth_mm(dose_j_cm2: float) -> float:
	var c := CareData.CURE_DEPTH
	var dp := float(c.dp_mm)
	var ec := float(c.ref_j_cm2) * V8.js_exp(-float(c.ref_mm) / dp)
	if dose_j_cm2 <= ec:
		return 0.0
	return dp * V8.js_log(dose_j_cm2 / ec)


## erfc (Abramowitz y Stegun 7.1.26, error < 1,5·10⁻⁷).
static func erfc(x: float) -> float:
	if x < 0.0:
		return 2.0 - erfc(-x)
	var t := 1.0 / (1.0 + 0.3275911 * x)
	var poly := t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))))
	return poly * V8.js_exp(-x * x)


## Inversa de erfc en [0, 1] por bisección (para la hondura a la que llega una temperatura).
static func erfc_inv(y: float) -> float:
	if y >= 1.0:
		return 0.0
	if y <= 0.0:
		return 6.0
	var lo := 0.0
	var hi := 6.0
	for i in 60:
		var mid := 0.5 * (lo + hi)
		if erfc(mid) > y:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)


## Soldar con TIG sobre la garra (petición 44): por qué no se puede, con sus números y sin hacérselo al animal. metal: el
## material de la pieza (ForgeData.MATERIALS, su temperatura de fusión); quick_mm: lo que hay de la unión a la carne viva
## (mm; la de la población si no se ve). Un sólido semiinfinito de queratina con la cara a la temperatura del baño
## (Carslaw y Jaeger): lo que se quema en contact_s y cuánto tardaría el calor en doler en la carne viva.
static func weld_report(metal: String, quick_mm: float) -> Dictionary:
	var m := ForgeData.material(metal)
	var melt: Variant = m.get("melt_c") if not m.is_empty() else null
	var th := CareData.THERMAL
	var bed := float(th.bed_c.value)
	var char_c := float(th.char_c.value)
	var pain := float(th.pain_c.value)
	var alpha := float(th.diffusivity_m2_s.value)
	var t := float(CareData.WELD.contact_s)
	var out := { "metal": metal, "meltC": null, "charC": char_c, "painC": pain, "burnMm": 0.0, "painS": null, "quickMm": quick_mm,
		"quickC1s": bed, "conducts": false, "text": "", "source": String(CareData.WELD.source) }
	var words := "La queratina seca no conduce la electricidad: el arco del TIG salta entre el electrodo y la pieza conectada a masa, y sobre la garra no salta."
	if melt == null:
		out["text"] = words + " Además, la queratina no se funde ni se mezcla con ningún metal: no hay soldadura posible. Lo real que se le parece: la masilla de epoxi con carga de acero («soldadura en frío»)."
		return out
	var tm := float((melt as Dictionary).value)
	out["meltC"] = tm
	# hondura (mm) a la que llega la temperatura de quemarse en t segundos con la cara a la del baño
	var burn := 2.0 * sqrt(alpha * t) * erfc_inv((char_c - bed) / (tm - bed)) * 1000.0
	out["burnMm"] = burn
	var x := maxf(quick_mm, 0.0) / 1000.0
	var arg := erfc_inv((pain - bed) / (tm - bed))
	var t_pain := (x / (2.0 * arg)) * (x / (2.0 * arg)) / alpha if arg > 0.0 else 0.0
	out["painS"] = t_pain
	# la carne viva al cabo de contact_s: T = T₀ + (T_baño − T₀)·erfc(x / (2·√(α·t)))
	var q1 := bed + (tm - bed) * erfc(x / (2.0 * sqrt(alpha * t))) if x > 0.0 else tm
	out["quickC1s"] = q1
	out["text"] = "%s El baño de soldadura está a ~%s °C (la fusión del %s) y la queratina se quema a ~%s °C: en %s s con el baño tocándola se quemarían ~%s mm de garra; en ese segundo la carne viva, a ~%s mm, seguiría a ~%s °C (el calor aún no ha llegado), pero si el baño siguiera ahí, llegaría y dolería (%s °C) en ~%s s. La queratina no se funde ni se mezcla con el metal: no hay soldadura posible. Lo real que se le parece: la masilla de epoxi con carga de acero («soldadura en frío»), un adhesivo que llena holguras, cura en horas y se lima. Soldar metal con metal (TIG o láser) se hace en el laboratorio, antes de colocar la pieza." % [
		words, Js.to_fixed(tm, 0), String(ForgeData.inlay_entry(metal).name).to_lower() if ForgeData.inlay_entry(metal) != null else metal,
		Js.to_fixed(char_c, 0), Js.to_fixed(t, 0), Js.to_fixed(burn, 1), Js.to_fixed(quick_mm, 1), Js.to_fixed(q1, 1), Js.to_fixed(pain, 0), Js.to_fixed(t_pain, 0)]
	out["source"] = String(CareData.WELD.source) + "; " + String((melt as Dictionary).get("source", ""))
	return out


## Un tiempo en palabras: «20 s», «5 min», «3 h», «1,5 días».
static func dur(s: float) -> String:
	if s < 90.0:
		return "%s s" % Js.to_fixed(s, 0)
	if s < 5400.0:
		return "%s min" % Js.to_fixed(s / 60.0, 0)
	if s < 129600.0:
		var h := s / 3600.0
		return "%s h" % Js.to_fixed(h, 1 if h < 10.0 else 0)
	return "%s días" % Js.to_fixed(s / 86400.0, 1)


# ════════════════════════════════ Preparar ════════════════════════════════

func _touch() -> void:
	serial += 1


## Elige el método (si la pieza lo admite). Solo antes de empezar a pegar.
func set_method(m: String) -> bool:
	if not (piece.get("methods", []) as Array).has(m) or started():
		return false
	method = m
	_touch()
	return true


## Elige el adhesivo (antes de ponerlo).
func set_adhesive(id: String) -> bool:
	if not ADHESIVE_IDS.has(id) or applied_t >= 0.0:
		return false
	if id != adhesive:
		adhesive = id
		purged = false
	_touch()
	return true


## ¿Ya se ha empezado a pegar (adhesivo puesto, una mezcla o una capa)?
func started() -> bool:
	return applied_t >= 0.0 or not mix.is_empty() or not layers.is_empty() or not resin.is_empty()


## Limpiar y desengrasar: con alcohol (se evapora solo en alcohol_dry_s) o con clorhexidina (es agua: queda mojada hasta
## secarla con la gasa).
func clean(with: String, now: float) -> bool:
	if not CLEANERS.has(with) or started():
		return false
	cleaner = with
	clean_t = now
	wet = with == "clorhexidina"
	notice = "Limpia con %s: %s" % ["alcohol" if with == "alcohol" else "clorhexidina", "se evapora en unos segundos." if with == "alcohol" else "queda mojada: sécala con una gasa."]
	_touch()
	return true


## Secar con la gasa: press_s segundos de gasa apretada. La clorhexidina se seca con gauze_dry_s.
func dry(press_s: float, _now: float) -> void:
	if not wet:
		return
	if press_s >= float(CareData.BOND_PREP.gauze_dry_s) - 1e-9:
		wet = false
		notice = "Seca: la gasa se ha llevado el agua."
		_touch()


## ¿Está mojada ahora? La clorhexidina sin secar, o el alcohol que aún no se ha evaporado.
func is_wet(now: float) -> bool:
	if wet:
		return true
	return cleaner == "alcohol" and now - clean_t < float(CareData.BOND_PREP.alcohol_dry_s)


## Lija o lima donde va a pegar: la rugosidad que deja (µm, la de ClawCare.file: raUm). La más rugosa se queda.
func sand(ra: float) -> void:
	if started() or ra <= ra_um:
		return
	ra_um = ra
	notice = "Lijada donde va a pegar: Ra %s µm." % Js.to_fixed(ra, 2)
	_touch()


## ¿Lijada? Más rugosa que la natural (una pasada de lija o de lima deja más Ra: ClawCare.file); lo que aguanta lo dice
## rough_factor con la Ra que quede. SANDED_RA: la Ra que ya cuenta como lijada, frente a la natural (elección de la interfaz).
const SANDED_RA := 1.2


func sanded() -> bool:
	return ra_um >= SANDED_RA * float(CareData.SURFACE.natural_ra_um.value)


# ════════════════════════════════ Adhesivo: poner, colocar, sujetar ════════════════════════════════

## Purga la cánula de la jeringa doble (los de dos componentes).
func purge() -> bool:
	if method != "adhesivo" or applied_t >= 0.0 or int(adhesive_times(adhesive).get("parts", 1)) < 2:
		return false
	purged = true
	notice = "Purgada: lo primero que sale, con la proporción mal, se tira."
	_touch()
	return true


## Pone el adhesivo (en la pieza): empieza su tiempo de trabajo.
func apply_adhesive(now: float) -> bool:
	if method != "adhesivo" or applied_t >= 0.0 or not failure.is_empty():
		return false
	applied_t = now
	applied_purged = purged or int(adhesive_times(adhesive).get("parts", 1)) < 2
	notice = "Adhesivo puesto: hay %s para colocar la pieza." % dur(float(adhesive_times(adhesive).work_s))
	_touch()
	return true


## Coge la pieza de la bandeja (o la deja).
func grab(on: bool = true) -> bool:
	if not placed.is_empty() or fixed_t >= 0.0:
		return false
	held = on
	_touch()
	return true


## Gira la pieza en la mano (grados; la tecla o el arrastre) y apunta (mm del centro del muñón).
func turn(d_deg: float) -> void:
	if held and placed.is_empty():
		tilt_deg = clampf(tilt_deg + d_deg, -45.0, 45.0)
		_touch()


func aim(offset_mm: float, docked: bool = true) -> void:
	if held and placed.is_empty():
		aim_mm = maxf(offset_mm, 0.0)
		aim_docked = docked
		_touch()


## Pone la pieza sobre el muñón (y la empieza a sujetar con la mano): con el adhesivo puesto y dentro de su tiempo de
## trabajo. Rebosa lo que sobra.
func place(now: float, offset_mm: float = -1.0) -> bool:
	if method != "adhesivo" or not held or not placed.is_empty():
		return false
	if float(piece.get("gapMm", 0.0)) < 0.0:
		# la prueba del ajuste del laboratorio (5m): una colada que encogió sin compensar no entra en la garra
		notice = "No entra: la pieza salió %s mm más estrecha por dentro que la garra (la contracción de la colada sin compensar). Se arregla en el laboratorio: otra colada con la cera a la medida, o abrir el hueco con la fresa." % Js.to_fixed(-float(piece.gapMm), 3)
		_touch()
		return false
	if applied_t < 0.0:
		notice = "Primero el adhesivo: sin él la pieza no se pega."
		_touch()
		return false
	if offset_mm < 0.0 and not aim_docked:
		notice = "La pieza no está sobre el muñón: llévala hasta él (la silueta de la forma sana te dice dónde) y aprieta ahí."
		_touch()
		return false
	var off := aim_mm if offset_mm < 0.0 else offset_mm
	var late := now - applied_t > float(adhesive_times(adhesive).work_s)
	placed = { "t": now, "offset": off, "tilt": tilt_deg }
	held = false
	holding = true
	hold_t = now
	moved_mm = 0.0
	var a := adhesive_data(adhesive)
	# el escalón del borde de la funda: el adhesivo de la holgura y lo descentrada que quede (el borde de la funda llega afilado
	# de la reforja: suposición del modelo); se rellena con lo que rebosa y se lima como el adhesivo curado
	if String(piece.get("kind", "")) == "funda":
		step_mm = minf(float(piece.gapMm), float(a.get("gap_max", 0.0))) + off
	flash_mm3 = maxf(float(CareData.BOND_FLASH.min_mm3), minf(float(piece.gapMm), float(a.get("gap_max", 0.0))) * float(piece.areaMm2) * float(CareData.BOND_FLASH.overfill))
	if late:
		failure = "pasada"
		notice = "Tarde: el adhesivo ya había empezado a curar (tiempo de trabajo, %s). Hay que quitarla, limpiar y poner adhesivo nuevo." % dur(float(adhesive_times(adhesive).work_s))
	elif absf(tilt_deg) > float(CareData.BOND_ALIGN.tilt_deg) or off > float(CareData.BOND_ALIGN.offset_mm):
		failure = "torcida"
		notice = "Torcida: %s° del eje de la garra y %s mm del centro (se toleran %s° y %s mm). Quítala y vuelve a colocarla." % [Js.to_fixed(absf(tilt_deg), 0), Js.to_fixed(off, 1), Js.to_fixed(float(CareData.BOND_ALIGN.tilt_deg), 0), Js.to_fixed(float(CareData.BOND_ALIGN.offset_mm), 1)]
	else:
		notice = "Colocada y alineada. Sujétala quieta hasta que fije: %s (en la vida real)." % dur(float(adhesive_times(adhesive).fix_s))
	_touch()
	return true


## Lo que se mueve la mano mientras la sujeta (mm): pasado BOND_HOLD_TOL_MM antes de fijar, se mueve y se despega.
func move(mm: float, now: float) -> void:
	if not holding or fixed_t >= 0.0 or wrapped:
		return
	moved_mm += absf(mm)
	if moved_mm > float(CareData.BOND_HOLD_TOL_MM) and failure.is_empty():
		failure = "movida"
		notice = "Se ha movido mientras fijaba (%s mm): queda despegada por dentro. Quítala y empieza de nuevo." % Js.to_fixed(moved_mm, 1)
		_touch()
	update(now)


## Venda o cinta: la sujeta quieta sin la mano (las colas lentas).
func wrap(now: float) -> bool:
	if placed.is_empty() or wrapped or not holding:
		return false
	wrapped = true
	wrap_t = now
	notice = "Vendada: la venda la sujeta mientras fija; luego hay que quitarla."
	_touch()
	return true


func unwrap(now: float) -> bool:
	if not wrapped:
		return false
	update(now)
	wrapped = false
	if fixed_t < 0.0 and not holding and failure.is_empty():
		failure = "suelta"
		notice = "La venda se ha quitado antes de que fije: la pieza se suelta. Quítala y empieza de nuevo."
	else:
		notice = "Venda quitada."
	_touch()
	return true


## Suelta la mano. Antes de fijar (y sin venda), la pieza se suelta o se tuerce.
func let_go(now: float) -> void:
	if not holding:
		return
	update(now)
	holding = false
	if fixed_t < 0.0 and not wrapped and failure.is_empty():
		var t := now - float(placed.get("t", now))
		failure = "suelta" if t < 0.5 * float(adhesive_times(adhesive).fix_min) else "torcida"
		notice = "Soltada a los %s; fija en %s: %s. Quítala y empieza de nuevo." % [dur(t), dur(float(adhesive_times(adhesive).fix_s)), "se ha soltado" if failure == "suelta" else "se ha torcido al resbalar"]
	_touch()


## Pasa el tiempo (now: s del ensayo): fija si se ha sujetado quieta el tiempo de fijación; la lámpara.
func update(now: float) -> void:
	if method == "adhesivo" and fixed_t < 0.0 and failure.is_empty() and not placed.is_empty() and (holding or wrapped):
		var tp := float(placed.t)
		if now - tp >= float(adhesive_times(adhesive).fix_s) - 1e-9:
			fixed_t = tp + float(adhesive_times(adhesive).fix_s)
			notice = "Ha fijado: ya aguanta su peso. Seguirá curando hasta la plena resistencia (%s)." % dur(float(adhesive_times(adhesive).full_s))
			_touch()
	if lamp_on and now >= lamp_end - 1e-9:
		_lamp_off(lamp_end)
	# el acrílico: el aviso al fraguar la última capa (una vez por capa)
	if method == "acrilico" and not layers.is_empty() and not bool(layers.back().get("set_noted", false)) and done_building() and set_all(now):
		layers.back()["set_noted"] = true
		notice = "Ha fraguado: ya está duro. Ahora se lima: lo que rebosa, el escalón de la unión y la forma (la amoladora, toques cortos)."
		_touch()


## Quita la pieza (despegada, torcida o para empezar de nuevo): vuelve a la bandeja; hay que limpiar el adhesivo y preparar
## otra vez (la queratina queda como estaba).
func remove() -> void:
	placed = {}
	holding = false
	wrapped = false
	held = false
	step_mm = 0.0
	fixed_t = -1.0
	failure = ""
	applied_t = -1.0
	purged = false
	flash_mm3 = 0.0
	cleaner = ""
	wet = false
	moved_mm = 0.0
	tilt_deg = float(CareData.BOND_ALIGN.start_tilt_deg)
	aim_mm = 0.0
	aim_docked = true
	test = {}
	notice = "Quitada: limpia los restos y vuelve a preparar la garra."
	_touch()


# ════════════════════════════════ El acrílico dental ════════════════════════════════

## Mezcla polvo y líquido (ratio, en peso) para una capa.
func mix_acrylic(ratio: float, now: float) -> bool:
	if method != "acrilico" or done_building():
		return false
	mix = { "t": now, "ratio": ratio }
	notice = "Mezclado (%s:1 en peso): espera a la masa (~%s) y aplícala antes de %s." % [Js.to_fixed(ratio, 1), dur(float(CareData.ACRYLIC_MIX.dough_s)), dur(float(CareData.ACRYLIC_MIX.work_s))]
	_touch()
	return true


## La fase de la mezcla del vaso: «» sin mezcla, «liquida», «masa», «dura» (ya no se modela) o «fraguada».
func mix_phase(now: float) -> String:
	if mix.is_empty():
		return ""
	var t := now - float(mix.t)
	var m := CareData.ACRYLIC_MIX
	if t < float(m.dough_s):
		return "liquida"
	if t < float(m.work_s):
		return "masa"
	if t < float(m.set_s):
		return "dura"
	return "fraguada"


## Aplica una capa del vaso sobre el muñón (o sobre la anterior) con la espátula: «fina» o «gruesa» (CareData.LAYER_MM).
## Solo en la fase de masa. Devuelve el alto (mm) aplicado (0 si no se ha podido).
func apply_layer(kind: String, now: float) -> float:
	if method != "acrilico" or mix.is_empty():
		return 0.0
	var ph := mix_phase(now)
	if ph == "liquida":
		notice = "Aún está líquida: chorrea. Espera a la fase de masa."
		_touch()
		return 0.0
	if ph != "masa":
		notice = "Ya ha pasado el tiempo de trabajo: no se pega ni se modela. Mezcla otra."
		mix = {}
		_touch()
		return 0.0
	var h := minf(float(CareData.LAYER_MM.get(kind, 1.0)), float(piece.needMm) - built_mm)
	if h <= 0.0:
		return 0.0
	var r := float(piece.stumpRadiusMm) + float(piece.wallMm)
	built_mm += h
	layers.append({ "t_mix": float(mix.t), "t_apply": now, "h": h, "top": float(piece.jointMm) + built_mm, "q": acrylic_heat_j(h, r, float(mix.ratio)), "ratio": float(mix.ratio) })
	flash_mm3 += float(CareData.BOND_FLASH.min_mm3)
	mix = {}
	notice = "Capa de %s mm aplicada (%s de %s mm). Fragua en ~%s y se calienta." % [Js.to_fixed(h, 1), Js.to_fixed(built_mm, 1), Js.to_fixed(float(piece.needMm), 1), dur(float(CareData.ACRYLIC_MIX.set_s))]
	_touch()
	return h


func done_building() -> bool:
	return float(piece.get("needMm", 0.0)) > 0.0 and built_mm >= float(piece.needMm) - 1e-6


## La energía (J) que desprenden las capas de acrílico entre a y b (s del ensayo): la de cada capa desde que se aplicó.
func heat_between(a: float, b: float) -> float:
	var e := 0.0
	for l: Dictionary in layers:
		var lo := maxf(a, float(l.t_apply)) - float(l.t_mix)
		var hi := b - float(l.t_mix)
		if hi > lo:
			e += float(l.q) * (acrylic_heat_cdf(hi) - acrylic_heat_cdf(lo))
	return e


## El alto (mm) de las capas que aún desprenden calor en now, y dónde acaba la de arriba (mm desde la base).
func reacting_span(now: float) -> Array:
	var h := 0.0
	var top := float(piece.get("jointMm", 0.0)) + built_mm
	for l: Dictionary in layers:
		if now - float(l.t_mix) < float(CareData.ACRYLIC_MIX.set_s):
			h += float(l.h)
	return [h, top]


## ¿Ha fraguado todo el acrílico (o curado toda la resina)?
func set_all(now: float) -> bool:
	if method == "acrilico":
		if layers.is_empty() or not done_building():
			return false
		for l: Dictionary in layers:
			if now - float(l.t_mix) < float(CareData.ACRYLIC_MIX.set_s):
				return false
		return true
	if method == "resina":
		if resin.is_empty() or not done_building() or lamp_on:
			return false
		for l: Dictionary in resin:
			if float(l.cured) < 1.0:
				return false
		return true
	return fixed_t >= 0.0


# ════════════════════════════════ La resina con la lámpara ════════════════════════════════

func set_lamp(id: String, d_mm: float, secs: float) -> void:
	if CareData.LAMPS.has(id):
		lamp = id
	lamp_mm = clampf(d_mm, 0.0, 40.0)
	lamp_s = clampf(secs, 1.0, 120.0)
	_touch()


func cover_eyes(on: bool = true) -> void:
	eyes_covered = on
	_touch()


## Pone una capa de resina (sin curar).
func apply_resin(kind: String) -> float:
	if method != "resina" or lamp_on:
		return 0.0
	if not resin.is_empty() and float(resin.back().dose) <= 0.0:
		notice = "Primero cura la capa que hay: sin luz se queda blanda."
		_touch()
		return 0.0
	var h := minf(float(CareData.LAYER_MM.get(kind, 1.0)), float(piece.needMm) - built_mm)
	if h <= 0.0:
		return 0.0
	built_mm += h
	resin.append({ "h": h, "dose": 0.0, "cd": 0.0, "cured": 0.0 })
	flash_mm3 += float(CareData.BOND_FLASH.min_mm3)
	notice = "Capa de resina de %s mm: cúrala con la lámpara." % Js.to_fixed(h, 1)
	_touch()
	return h


## Enciende la lámpara (se apaga sola al acabar su intervalo, como las de verdad). Con los ojos tapados.
func lamp_start(now: float) -> bool:
	if method != "resina" or resin.is_empty() or lamp_on:
		return false
	if not eyes_covered:
		notice = "Primero el filtro naranja y los ojos del animal tapados (la capucha): la luz azul intensa daña la retina."
		_touch()
		return false
	lamp_on = true
	lamp_t = now
	lamp_end = now + lamp_s
	_touch()
	return true


func _lamp_off(at: float) -> void:
	var l: Dictionary = resin.back()
	var secs := maxf(at - lamp_t, 0.0)
	l["dose"] = float(l.dose) + irradiance_at(lamp, lamp_mm) * secs / 1000.0
	l["cd"] = cure_depth_mm(float(l.dose))
	l["cured"] = clampf(float(l.cd) / float(l.h), 0.0, 1.0)
	lamp_on = false
	notice = ("Curada: la luz llega a %s mm y la capa mide %s mm." if float(l.cured) >= 1.0 else "Blanda por dentro: la luz solo cura %s mm de los %s mm de la capa. Más tiempo, más cerca o capas más finas.") % [Js.to_fixed(float(l.cd), 1), Js.to_fixed(float(l.h), 1)]
	_touch()


## Los pitidos de la lámpara desde la última vez (cada beep_s): cuántos hay hasta now.
func lamp_beeps(now: float) -> int:
	if lamp_t < 0.0:
		return 0
	var bs := float((CareData.LAMPS[lamp] as Dictionary).beep_s)
	var until := minf(now, lamp_end)
	return int(floor((until - lamp_t) / bs + 1e-9))


# ════════════════════════════════ Lo que rebosa, el escalón y la prueba ════════════════════════════════

## ¿Está aún fresco (blando) lo que rebosa?
func fresh(now: float) -> bool:
	match method:
		"adhesivo":
			return not placed.is_empty() and fixed_t < 0.0 and now - float(placed.t) < float(adhesive_times(adhesive).fix_s)
		"acrilico":
			return not layers.is_empty() and now - float(layers.back().t_mix) < float(CareData.ACRYLIC_MIX.set_s)
	return not resin.is_empty() and float(resin.back().dose) <= 0.0


## Una pasada de la espátula sobre lo que rebosa: en fresco se lleva scrape; duro, no.
func scrape(now: float) -> bool:
	if flash_mm3 <= 0.0:
		return false
	if not fresh(now):
		notice = "Ya está duro: lo que rebosa se quita con la lima."
		_touch()
		return false
	flash_mm3 *= 1.0 - float(CareData.BOND_FLASH.scrape)
	if flash_mm3 < float(CareData.BOND_FLASH.clean_mm3):
		flash_mm3 = 0.0
	notice = "Espátula: quedan %s mm³ de lo que rebosa." % Js.to_fixed(flash_mm3, 2)
	_touch()
	return true


## Una pasada de lima que arranca mm3 del cordón duro (lo calcula el estado con ClawCare.removal_mm3 y la dureza del
## polímero curado, CareData.BOND_JOINT). Devuelve lo que se ha llevado.
func file_flash(mm3: float) -> float:
	if flash_mm3 <= 0.0 or mm3 <= 0.0:
		return 0.0
	var took := minf(mm3, flash_mm3)
	flash_mm3 -= took
	if flash_mm3 < float(CareData.BOND_FLASH.clean_mm3):
		flash_mm3 = 0.0
	_touch()
	return took


## Una pasada de lima sobre el borde de la funda que baja el escalón depth_mm.
func file_step(depth_mm: float) -> void:
	if step_mm <= 0.0 or depth_mm <= 0.0:
		return
	step_mm = maxf(step_mm - depth_mm, 0.0)
	_touch()


## ¿Está la pieza unida a la garra (la ClawCare la lleva puesta)? El adhesivo, al fijar; el acrílico, con la primera capa;
## la resina, con la primera capa curada.
func attached() -> bool:
	match method:
		"adhesivo":
			return fixed_t >= 0.0 and failure.is_empty()
		"acrilico":
			return not layers.is_empty()
	return not resin.is_empty() and float(resin[0].dose) > 0.0


## Lo que aguanta la unión ahora: { capN, tauMPa, adhesiveMPa, keratinMPa, limitedBy, cures, factors: { clean, rough,
## purge, cure, ratio, wet }, reasons: [ … ] }. humidity: la de la garra.
func capacity(now: float, humidity: String) -> Dictionary:
	var hum := "humeda" if is_wet(now) and not (humidity in ["humeda", "empapada"]) else humidity
	var adh := adhesive if method == "adhesivo" else "metacrilato"
	var gap := float(piece.get("gapMm", 0.0)) if method == "adhesivo" else 0.0
	var base := base_capacity(adh, gap, float(piece.get("areaMm2", 0.0)), hum)
	var f := { "clean": 1.0, "rough": rough_factor(adh, ra_um), "purge": 1.0, "cure": 1.0, "ratio": 1.0, "wet": hum != humidity }
	if cleaner == "":
		f["clean"] = float(CareData.BOND_PREP.dirty_metacrilato if adh == "metacrilato" else CareData.BOND_PREP.dirty)
	match method:
		"adhesivo":
			f["purge"] = 1.0 if applied_purged else float(CareData.BOND_PURGE.purge_off)
			f["cure"] = cure_fraction(adh, now - float(placed.t)) if not placed.is_empty() and failure.is_empty() else 0.0
		"acrilico":
			var worst := 1.0
			var cure := 1.0
			for l: Dictionary in layers:
				worst = minf(worst, ratio_factor(float(l.ratio)))
				var t := now - float(l.t_mix)
				var m := CareData.ACRYLIC_MIX
				var c := 0.0
				if t >= float(m.set_s):
					c = minf(1.0, 0.5 + 0.5 * V8.js_log(t / float(m.set_s)) / V8.js_log(float(m.full_s) / float(m.set_s)))
				cure = minf(cure, c)
			f["ratio"] = worst
			f["cure"] = cure if not layers.is_empty() else 0.0
		"resina":
			var cr := 1.0
			for l: Dictionary in resin:
				cr = minf(cr, float(l.cured))
			f["cure"] = cr if not resin.is_empty() else 0.0
	var t_adh := float(base.adhesiveMPa) * float(f.clean) * float(f.rough) * float(f.purge) * float(f.cure) * float(f.ratio)
	var t_ker := float(base.keratinMPa)
	var tau := minf(t_adh, t_ker)
	var by := "holgura" if not bool(base.cures) else ("queratina" if t_ker < t_adh else "adhesivo")
	var reasons: Array = []
	if not failure.is_empty():
		reasons.append(failure)
	if not bool(base.cures):
		reasons.append("holgura")
	if float(f.cure) < CURED_WORDS:
		reasons.append("sin_curar")
	if float(f.clean) < 1.0:
		reasons.append("sucia")
	if bool(f.wet):
		reasons.append("mojada")
	if float(f.rough) < 0.9:
		reasons.append("lisa")
	if float(f.purge) < 1.0:
		reasons.append("sin_purgar")
	if float(f.ratio) < 1.0:
		reasons.append("proporcion")
	return { "capN": tau * float(piece.get("areaMm2", 0.0)), "tauMPa": tau, "adhesiveMPa": t_adh, "keratinMPa": t_ker, "limitedBy": by,
		"cures": bool(base.cures), "factors": f, "reasons": reasons, "adhesive": adh, "humidity": hum }


const REASON_WORDS := {
	"holgura": "la holgura es de más para ese adhesivo (no cura)",
	"sin_curar": "aún no ha curado",
	"sucia": "la garra estaba sucia (sin limpiar ni desengrasar)",
	"mojada": "la garra estaba mojada",
	"lisa": "la queratina estaba lisa (sin lijar)",
	"sin_purgar": "la cánula no se purgó (la proporción, mal)",
	"proporcion": "la proporción del polvo y el líquido no era la de la ficha",
	"movida": "se movió mientras fijaba",
	"torcida": "quedó torcida",
	"suelta": "se soltó antes de fijar",
	"pasada": "el adhesivo había pasado su tiempo de trabajo",
}


## La prueba: un tirón suave de lado con force_n (la mitad del agarre de la garra: CareData.BOND_TEST). Si no aguanta, se
## despega (y hay que quitarla) y el texto dice por qué.
func pull_test(now: float, humidity: String, force_n: float) -> Dictionary:
	update(now)
	var cap := capacity(now, humidity)
	var ok := attached() and float(cap.capN) >= force_n and failure.is_empty()
	var why: Array = []
	for r: String in cap.reasons:
		why.append(String(REASON_WORDS.get(r, r)))
	var text := ""
	if ok:
		text = "Aguanta: un tirón de %s de lado contra ~%s que aguanta la unión (manda %s)." % [_n(force_n), _n(float(cap.capN)), "la queratina" if cap.limitedBy == "queratina" else "el adhesivo"]
	else:
		text = "Se despega con un tirón de %s (aguantaba ~%s)%s" % [_n(force_n), _n(float(cap.capN)), (": " + ", ".join(why) + ".") if not why.is_empty() else "."]
	test = { "ok": ok, "forceN": force_n, "capN": float(cap.capN), "reasons": cap.reasons.duplicate(), "text": text, "t": now }
	notice = text
	if not ok:
		failure = "despegada" if failure.is_empty() else failure
	_touch()
	return test.duplicate(true)


static func _n(f: float) -> String:
	return "%s N" % Js.to_fixed(f, 0 if f >= 10.0 else 1)


## ¿Ha acabado la colocación (unida, sin lo que rebosa, sin escalón y probada)?
func finished(now: float, step_now: float) -> bool:
	return attached() and set_all(now) and flash_mm3 <= 0.0 and step_now <= float(CareData.BOND_JOINT.step_ok_mm) and bool(test.get("ok", false))


# ════════════════════════════════ Condiciones del tutorial ════════════════════════════════

## Las condiciones de los pasos de «Colocar la pieza» (claw_care_tutorial.gd): step_now, el escalón de ahora (mm).
func check(key: String, now: float, step_now: float = 0.0) -> bool:
	match key:
		"limpia":
			return cleaner != ""
		"seca":
			return cleaner != "" and not is_wet(now)
		"lijada":
			return sanded()
		"purgada":
			return purged or applied_t >= 0.0 and applied_purged
		"aplicado":
			return applied_t >= 0.0
		"colocada":
			return not placed.is_empty() and failure.is_empty()
		"fijada":
			return fixed_t >= 0.0 and failure.is_empty()
		"sin_venda":
			return fixed_t >= 0.0 and not wrapped
		"mezclado":
			return not mix.is_empty() or not layers.is_empty()
		"en_masa":
			return mix_phase(now) == "masa" or not layers.is_empty()
		"construida":
			return done_building()
		"fraguada", "curada":
			return set_all(now)
		"ojos":
			return eyes_covered
		"sin_rebaba":
			return attached() and flash_mm3 <= 0.0
		"sin_escalon":
			return attached() and step_now <= float(CareData.BOND_JOINT.step_ok_mm)
		"probada":
			return bool(test.get("ok", false))
	return false
