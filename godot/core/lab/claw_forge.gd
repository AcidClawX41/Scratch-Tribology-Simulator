## Tribología biológica · reforja experimental de garras: el proceso paso a paso (modelo 2.0, unidad 5d). Un objeto por
## garra (RefCounted, sin nodos ni variables estáticas mutables, determinista), de la misma familia que ClawCare: la escena
## del taller (el horno, la muela, la funda) lo mueve y pinta sus instantáneas. Datos con fuente: claw_forge_data.gd.
## Guía: docs/fisica/reforja.md.
##
## La regla de oro (la física de verdad): la garra viva no aguanta el calor (la queratina se quema a ~230 °C,
## CareData.THERMAL.char_c, y la carne viva duele desde ~43 °C). Todo lo caliente se hace aparte, como una funda, y se
## pega o se encaja en frío, como una corona dental. Recubrir la garra viva es FICCIÓN: el motor calcula lo que pasaría
## (con una barrera térmica encima de la carne viva) y lo marca «ficcion».
##
## Etapas (cada una con sus parámetros y su resultado):
##   1. Material: una receta del horno (mix y fire), una pieza comprada (choose: las gemas naturales) o, para una garra
##      rota, el acrílico dental de la prótesis de verdad (choose("acrilico"): sin horno y sin ficción; unidad 5j).
##   2. Horno (fire): el modo, la temperatura, el tiempo, la atmósfera, la presión y el molde, frente a la receta y a los
##      datos del material (fusión, oxidación, línea de Kennedy del diamante, ritmo de crecimiento). heat(): calentar una
##      pieza para ver qué le hace el calor (el diamante se quema al aire, el cuarzo cambia de fase a 573 °C…).
##   3. Enfriar (cool): choque térmico de Kingery con el factor de Manson (β = h·a/k); el vidrio se recuece; el cuarzo no
##      cruza 573 °C deprisa.
##   4. Tallar (carve): Archard con los granos de la cetrería (ClawCare.element_cut); el abrasivo tiene que ser más duro
##      (Contact.hardness_efficiency); el borde fino de una pieza frágil se desconcha con F = β·K_c·d^(3/2) (Chai y Lawn);
##      régimen dúctil por debajo de d_c (Bifano); tallar en seco agrieta lo frágil que conduce mal y quema el diamante.
##   5. Proteger la carne viva (protect) y recubrir (coat): en una funda aparte (real) o sobre la garra viva (ficción, con
##      la conducción por la barrera, la queratina y la carne viva, implícita, como la de ClawCare).
##   6. Unir (bond): adhesivo en frío; cortante = mín(adhesivo, queratina) × superficie de la funda; holgura máxima.
##   7. Pulir (polish): solo muerde lo más duro; deja la punta del grano (afilado de ClawSharpness).
##   8. Comprobar (check_load): la carga de la garra contra lo que aguanta la unión. La garra resultante (result_claw) pasa
##      al banco, al coche en marcha y a la cetrería con su material, su dureza, su módulo, su masa y su afilado.
## La garra rota (petición 35; unidad 5j): la funda o la prótesis se hace para la garra de su dedo y con lo que queda de
## ella (configure: digit, paw, stump_mm), y vuelve a la cetrería como un bloque (care_setup). La pieza tallada o pulida
## lleva la rugosidad de la última muela o del último grano (surface). El sonido de la marcha es el de la máquina del modo
## del horno (machine_for, machine_sfx).
## Soldar (5r; petición 44): dos piezas de metal de la funda (la punta y la base, o una funda rota) se unen en el laboratorio
## por láser, micro-TIG o soldadura fuerte (ClawWeld): weld_setup, weld_pulse (cada punto a lo largo de la costura) y
## weld_finish; la costura deja un cordón que se lima con la muela fina (carve_pass) y la unión va a la cetrería con lo que
## aguanta (care_setup().piece.weld). Sobre la queratina, nunca: lo explica la cetrería.
## Qué no predice: docs/fisica/reforja.md §9. Unidades: mm · N · °C · s · MPa · HV.
## Uso:
##   const ClawForge = preload("res://core/lab/claw_forge.gd")
##   var f := ClawForge.new({ "animal": "rapaz", "claw": "aguila", "recipe": "zafiro" })
##   f.mix({ "al2o3": 50.0 })
##   f.fire({ "mode": "sintetizar", "temp_c": 2100, "time_s": 7200, "atmosphere": "aire", "pressure_mpa": 0.101 })
##   f.cool("aire"); f.carve({ "abrasive": "diamante" }); f.protect({ "barrier": "aerogel", "thickness_mm": 3 })
##   f.bond({ "adhesive": "epoxi", "gap_mm": 0.1 }); f.polish({ "abrasive": "diamante", "grain_um": 9 }); f.check_load({})
##   var claw := f.result_claw()       # material, dureza, módulo, masa, afilado… para el banco
extends RefCounted

const ForgeData = preload("res://core/lab/claw_forge_data.gd")
const CareData = preload("res://core/lab/claw_care_data.gd")
const ClawCare = preload("res://core/lab/claw_care.gd")
const ClawSharpness = preload("res://core/lab/claw_sharpness.gd")
const ClawMass = preload("res://core/lab/claw_mass.gd")
const Contact = preload("res://core/shared/contact.gd")
const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Format = preload("res://core/shared/format.gd")
const Tutorial = preload("res://core/lab/claw_forge_tutorial.gd")
const ClawWeld = preload("res://core/lab/claw_weld.gd")

## Las etapas del proceso, en orden (stage() da la primera que falta; «recubrir» es opcional y no la exige). Desde la 5m
## (petición 43) el laboratorio acaba en la pieza pulida: pegarla (bond) y probarla con la carga (check_load) son de la cetrería.
const STAGES := ["material", "horno", "enfriar", "tallar", "proteger", "recubrir", "pulir", "hecho"]
## Temperatura del taller (°C): de la que parte todo y a la que se enfría.
const ROOM_C := 20.0
## Pasos de la integración de la forma de la funda.
const SHEATH_STEPS := 200
## Celdas del modelo térmico de la barrera (mm): barrera y queratina, y tejido vivo.
const SLAB_DX_MM := 0.05
const SLAB_LIVE_DX_MM := 0.1
## Pasos de tiempo del modelo térmico de la barrera: entre MIN y MAX, de ~0,05 s.
const SLAB_STEPS_MIN := 200
const SLAB_STEPS_MAX := 4000
## Conductividad (W/(m·K)) por debajo de la cual una pieza frágil tallada en seco se agrieta por el calor del roce (el
## vidrio, el cuarzo y la circonita; no el zafiro ni el carburo). Regla del modelo (ForgeData.SRC_LAPIDARY).
const DRY_CRACK_K := 10.0
## Sonidos propuestos (ids nuevos para la parte de interfaz) y los del laboratorio que ya existen.
const SFX_FORGE := ["forja-muela", "forja-horno", "forja-llama", "forja-induccion", "forja-prensa", "forja-colada", "forja-temple", "forja-pulso", "forja-arco"]
const SFX_LAB := ["snap", "shatter", "tap", "press", "skin-cut", "scratch-glass", "scratch-metal", "slide", "drip"]

var _setup: Dictionary = {}
var _animal: Dictionary = {}
var _claw: Dictionary = {}
## La forma de la garra de su dedo (CareData.claw_shape: largo y alto de la base frente a la del banco) y su largo natural
## (mm): la funda o la prótesis se hace para esa garra (unidad 5j).
var _shape: Dictionary = {}
var _L := 35.0
## La garra rota (unidad 5j): lo que falta de ella desde su punta natural (mm; 0 si está entera). La prótesis es maciza ahí
## y solo se pega sobre lo que queda (el muñón, hasta stump_mm desde la base).
var _gone_mm := 0.0
var _care: Variant = null
var _recipe: Dictionary = {}
var _cover_mm := 0.0
var _wall_mm := 1.0
var _humidity := "natural"
var _sheath: Dictionary = {}

var _mix: Dictionary = {}
var _mix_eval: Dictionary = {}
var _fire: Dictionary = {}
var _piece: Dictionary = {}
var _cooled: Dictionary = {}
var _carved: Dictionary = {}
var _barrier: Dictionary = {}
var _coat: Dictionary = {}
var _bond: Dictionary = {}
var _polish: Dictionary = {}
var _check: Dictionary = {}
## Lo último que ha tocado bien la superficie de la pieza (unidad 5j): { by: «talla» (la muela), «pulido» (el grano) o
## «capa» (un recubrimiento sin pulir), material, raUm, chip }; {} en bruto. Decide la superficie que se ve (surface()); un
## intento que no muerde no la cambia.
var _surf: Dictionary = {}
## 5m · la carga metida en su máquina ({ machine, what }; procedimiento: la interfaz no arranca sin ella) y si el molde de la
## cera perdida está en el horno (se queda dentro, del quemado a la colada).
var _loaded: Dictionary = {}
var _mold_in := false
## 5m · la cera perdida: el modelo de cera, el revestimiento, el quemado de la cera y romper el molde.
var _wax: Dictionary = {}
var _invest: Dictionary = {}
var _burnout: Dictionary = {}
var _divest: Dictionary = {}
## 5m · el tallado por pasadas (carve_pass): lo que sobra, el hueco, los cortes de la sierra, el tiempo y la última herramienta.
var _cut: Dictionary = {}
## 5m · probar el ajuste de la funda en la garra, sin pegarla (petición 43).
var _fit: Dictionary = {}
## 5r · la soldadura de dos piezas de la funda: el método, la segunda pieza, los mandos, el punto, la costura (los tramos que
## llevan su punto), los pulsos dados y la unión que sale.
var _weld: Dictionary = {}
var _fiction: Array = []
var _events: Array = []
var _serial := 0


func _init(setup: Dictionary = {}) -> void:
	configure(setup)


# ════════════════════════════════ Ajustes ════════════════════════════════

## Empieza un proceso nuevo: { animal (CareData.ANIMAL_IDS), claw, recipe (ForgeData.RECIPE_IDS o «»), cover_mm (o
## cover_frac, la parte de la garra que cubre desde la punta), wall_mm, humidity (la de la queratina de la garra), digit y
## paw (la garra de ese dedo y de esa pata: CareData.claw_shape), stump_mm (la garra rota: lo que queda de ella, mm desde la
## base; la prótesis es maciza en lo que falta y se pega sobre el muñón) }.
func configure(setup: Dictionary) -> void:
	var s := setup.duplicate(true)
	var aid := String(s.get("animal", "rapaz"))
	if not CareData.ANIMALS.has(aid):
		aid = "rapaz"
	_animal = CareData.animal(aid)
	var cid := String(s.get("claw", _animal.claw))
	if not (_animal.claws as Array).has(cid):
		cid = String(_animal.claw)
	_claw = CareData.claw_entry(cid)
	var digit := String(s.get("digit", ""))
	var paw := String(s.get("paw", ""))
	_shape = CareData.claw_shape(cid, digit, paw.begins_with("trasera"))
	_L = float(_claw.reach) * float(_shape.lengthRatio)
	_care = ClawCare.new({ "animal": aid, "claw": cid, "digit": digit, "paw": paw, "overgrowth_days": 0.0 })
	var rid := String(s.get("recipe", ""))
	_recipe = ForgeData.recipe(rid)
	_humidity = String(s.get("humidity", "natural"))
	if not CareData.KERATIN.has(_humidity):
		_humidity = "natural"
	var cover := float(s.get("cover_mm", float(s.get("cover_frac", ForgeData.SHEATH.cover_frac)) * _L))
	_cover_mm = clampf(cover, 0.5, _L)
	_wall_mm = clampf(float(s.get("wall_mm", ForgeData.SHEATH.wall_mm)), 0.05, 10.0)
	_gone_mm = 0.0
	if s.has("stump_mm"):
		var stump := clampf(float(s.stump_mm), 0.0, _L)
		s["stump_mm"] = stump
		_gone_mm = _L - stump
	s["animal"] = aid
	s["claw"] = cid
	s["digit"] = String(_shape.digit)
	s["recipe"] = String(_recipe.get("id", ""))
	s["cover_mm"] = _cover_mm
	s["wall_mm"] = _wall_mm
	s["humidity"] = _humidity
	s.erase("cover_frac")
	_setup = s
	_sheath = sheath_geometry(_claw, _cover_mm, _wall_mm, _gone_mm, _shape)
	_mix = {}
	_mix_eval = {}
	_fire = {}
	_piece = {}
	_cooled = {}
	_carved = {}
	_barrier = {}
	_coat = {}
	_bond = {}
	_polish = {}
	_surf = {}
	_check = {}
	_loaded = {}
	_mold_in = false
	_wax = {}
	_invest = {}
	_burnout = {}
	_divest = {}
	_cut = {}
	_fit = {}
	_weld = {}
	_fiction = []
	_events = []
	_serial += 1


func setup() -> Dictionary:
	return _setup.duplicate(true)


## El largo natural de la garra de este dedo (mm): el del banco por el de su dedo (CareData.claw_shape).
func natural_mm() -> float:
	return _L


func serial() -> int:
	return _serial


func events() -> Array:
	return _events.duplicate(true)


func _event(code: String, message: String, source: String) -> void:
	_events.append({ "code": code, "message": message, "source": source })


# ════════════════════════════════ Catálogo (estático) ════════════════════════════════

## Las recetas por material objetivo, para la interfaz: [{ id, name, product, productName, inBench, benchTwin, variety, mode,
## method, form, powders [{ id, name, formula, what, value, min, max, source }], temp_c, time_s, atmosphere, pressure_mpa,
## mold, methane, growth, cool, quality, source }] (cada parámetro con su margen y sus defectos low/high).
static func recipes() -> Array:
	var out: Array = []
	for rid: String in ForgeData.RECIPE_IDS:
		out.append(recipe_card(rid))
	return out


## Una receta para pintarla (copia, con los nombres de los polvos y del producto).
static func recipe_card(rid: String) -> Dictionary:
	var r := ForgeData.recipe(rid)
	if r.is_empty():
		return {}
	var pw: Array = []
	for p: Dictionary in r.powders:
		var d: Dictionary = ForgeData.POWDERS[p.id]
		pw.append({ "id": p.id, "name": d.name, "formula": d.formula, "what": d.what, "value": p.value, "min": p.min, "max": p.max, "source": d.source })
	var prod: Variant = ForgeData.inlay_entry(String(r.product))
	r["powders"] = pw
	r["productName"] = String(prod.name) if prod != null else String(r.product)
	r["inBench"] = ForgeData.in_bench(String(r.product))
	r["benchTwin"] = ForgeData.bench_twin(String(r.product))
	return r


## Los mandos del horno (copia).
static func controls() -> Array:
	return ForgeData.CONTROLS.duplicate(true)


# ════════════════════════════════ Física pura (estática) ════════════════════════════════

## Presión (MPa) de la línea de Kennedy a la temperatura t_c: P (kbar) = 19,4 + T/40; por encima, el diamante es estable.
static func kennedy_mpa(t_c: float) -> float:
	return (19.4 + t_c / 40.0) * 100.0


## Temperatura (°C) más alta a la que el diamante es estable con la presión p_mpa (inversa de la línea de Kennedy).
static func kennedy_t_max(p_mpa: float) -> float:
	return (p_mpa / 100.0 - 19.4) * 40.0


## Salto de temperatura (K) que aguanta una pieza frágil con un enfriamiento brusco (Kingery): σ·(1 − ν)/(E·α).
## sigma_mpa, e_gpa, alpha (1/K).
static func shock_dt(sigma_mpa: float, e_gpa: float, alpha: float, nu: float = ForgeData.NU) -> float:
	if e_gpa <= 0.0 or alpha <= 0.0:
		return INF
	return sigma_mpa * (1.0 - nu) / (e_gpa * 1000.0 * alpha)


## Factor de Manson ψ (0-1): con un enfriamiento finito (β = h·a/k) la tensión es ψ veces la del salto brusco.
## 1/ψ = 1,5 + 3,25/β − 0,5·e^(−16/β). Con β → ∞, ψ → 1; con β → 0, ψ → 0.
static func manson_psi(beta: float) -> float:
	if beta <= 0.0:
		return 0.0
	return 1.0 / (1.5 + 3.25 / beta - 0.5 * V8.js_exp(-16.0 / beta))


## Salto de temperatura (K) que aguanta el material mat_id enfriado en el medio (ForgeData.COOLING) con la mitad del espesor
## a_mm: shock_dt/ψ. INF si el medio no da choque (horno), el material es dúctil o no hay datos.
static func shock_limit_c(mat_id: String, medium: String, a_mm: float) -> float:
	var m := ForgeData.material(mat_id)
	var st: Variant = ForgeData.strength_of(mat_id)
	var e: Variant = ForgeData.inlay_entry(mat_id)
	var cool: Dictionary = ForgeData.COOLING.get(medium, ForgeData.COOLING.aire)
	if m.is_empty() or st == null or e == null or String(st.kind) != "flexion" or m.alpha == null or m.k == null:
		return INF
	var h := float(cool.h)
	if h <= 0.0:
		return INF
	var beta := h * a_mm / 1000.0 / float(m.k.value)
	var psi := manson_psi(beta)
	if psi <= 0.0:
		return INF
	return shock_dt(float(st.value), float(e.E), float(m.alpha.value)) / psi


## Cuánto muerde un abrasivo de dureza abr_hv una pieza de work_hv (0-1): la eficiencia de la dureza del motor
## (Contact.hardness_efficiency) y, además, nunca si el abrasivo es más blando que la pieza (la prueba de la lima: una lima
## solo marca lo que es más blando que ella; ForgeData.SRC_FILE_TEST).
static func bite_efficiency(abr_hv: float, work_hv: float) -> float:
	if work_hv <= 0.0:
		return 1.0
	if abr_hv < work_hv:
		return 0.0
	return Contact.hardness_efficiency(abr_hv / work_hv)


## Fuerza (N) con la que una punta a d_mm del borde lo desconcha (Chai y Lawn 2007): β·K_c·d^(3/2).
static func edge_chip_n(kic_mpa_m: float, d_mm: float) -> float:
	var d := d_mm / 1000.0
	return float(ForgeData.EDGE_CHIP_BETA.value) * kic_mpa_m * 1.0e6 * d * sqrt(d)


## Hondura crítica del régimen dúctil (µm), d_c = 0,15·(E/H)·(K_c/H)² (Bifano et al. 1991).
static func ductile_depth_um(e_gpa: float, hv: float, kic_mpa_m: float) -> float:
	var h := hv * Contact.HV_MPA * 1.0e6
	var e := e_gpa * 1.0e9
	var q := kic_mpa_m * 1.0e6 / h
	return float(ForgeData.DUCTILE_REGIME_K.value) * (e / h) * q * q * 1.0e6


## Tiempo (s) de sinterizado de la alúmina a t_c (Coble): el logaritmo del tiempo en recta entre 24 h a 1700 °C y 7 h a
## 1900 °C (el centro de «6 a 8 h»), y la misma pendiente fuera de ese tramo.
static func alumina_time_s(t_c: float) -> float:
	var l0 := V8.js_log(24.0 * 3600.0)
	var l1 := V8.js_log(7.0 * 3600.0)
	var u := (t_c - 1700.0) / 200.0
	return V8.js_exp(l0 + (l1 - l0) * u)


## Estado del material mat_id a la temperatura t_c en la atmósfera atm: { melted, softened, oxidized, graphitized,
## inversion (cruzó la del cuarzo), noData }. Más temperatura nunca funde ni degrada menos.
static func heat_state(mat_id: String, t_c: float, atm: String) -> Dictionary:
	var m := ForgeData.material(mat_id)
	var out := { "melted": false, "softened": false, "oxidized": false, "graphitized": false, "inversion": false, "noData": m.is_empty() or (m.melt_c == null and m.soften_c == null and m.air_c == null and m.inversion_c == null) }
	if m.is_empty():
		return out
	if m.melt_c != null and t_c >= float(m.melt_c.value):
		out["melted"] = true
	if m.soften_c != null and t_c >= float(m.soften_c.value):
		out["softened"] = true
	if atm == "aire" and m.air_c != null and t_c >= float(m.air_c.value):
		out["oxidized"] = true
	if m.inert_c != null and t_c >= float(m.inert_c.value):
		out["graphitized"] = true
	if m.inversion_c != null and t_c >= float(m.inversion_c.value):
		out["inversion"] = true
	return out


## Cortante (MPa) que aguanta la queratina bajo la unión, en ese estado de humedad: σ·½·(relación entre capas).
static func keratin_shear_mpa(humidity: String) -> float:
	var k: Dictionary = CareData.keratin(humidity)
	return float(k.sigma_mpa) * float(ForgeData.KERATIN_SHEAR.tresca) * float(CareData.INTERLAMINAR.value)


## Lo que aguanta una unión pegada: { cures, tauMPa (el que manda), adhesiveMPa, keratinMPa, capacityN, limitedBy }.
## adhesive: ForgeData.ADHESIVES; gap_mm: holgura; area_mm2: superficie pegada; humidity: la de la garra. Más superficie
## nunca aguanta menos.
static func bond_capacity(adhesive: String, gap_mm: float, area_mm2: float, humidity: String) -> Dictionary:
	var a: Dictionary = ForgeData.ADHESIVES.get(adhesive, {})
	if a.is_empty():
		return { "cures": false, "tauMPa": 0.0, "adhesiveMPa": 0.0, "keratinMPa": 0.0, "capacityN": 0.0, "limitedBy": "sin_adhesivo" }
	var cures := gap_mm >= 0.0 and gap_mm <= float(a.gap_max)
	var wet := humidity in ["humeda", "empapada"]
	var t_adh := float(a.tau) * (float(a.wet) if wet else 1.0) if cures else 0.0
	var t_ker := keratin_shear_mpa(humidity)
	var tau := minf(t_adh, t_ker)
	var by := "holgura" if not cures else ("queratina" if t_ker < t_adh else "adhesivo")
	return { "cures": cures, "tauMPa": tau, "adhesiveMPa": t_adh, "keratinMPa": t_ker, "capacityN": tau * maxf(area_mm2, 0.0), "limitedBy": by }


## La funda de una garra (entrada del banco): cubre cover_mm desde la punta con wall_mm de pared. shape: la forma de la garra
## de su dedo (CareData.claw_shape: lengthRatio y baseRatio; sin ella, la del banco). gone_mm (la garra rota, unidad 5j): lo
## que falta de ella desde su punta natural; ahí la prótesis es maciza (no hay queratina dentro) y no se pega: solo se pega
## sobre lo que queda.
## { coverMm, wallMm, lengthMm, innerAreaMm2 (la superficie pegada), volumeMm3, outerRadiusMm (en el borde de la funda),
##   rawVolumeMm3 (el cilindro que la contiene, del que se talla), rawDiameterMm, keratinVolumeMm3 (la garra que queda),
##   naturalMm (el largo natural de la garra), goneMm (lo que falta), stumpCoverMm (lo que la funda cubre del muñón),
##   solidVolumeMm3 (la parte maciza que rehace lo que falta) }.
static func sheath_geometry(claw: Dictionary, cover_mm: float, wall_mm: float, gone_mm: float = 0.0, shape: Dictionary = {}) -> Dictionary:
	var reach := float(claw.reach) * float(shape.get("lengthRatio", 1.0))
	var base_r := ClawMass.CLAW_BASE * float(claw.reach) * float(shape.get("baseRatio", 1.0))
	var tip := Contact.tip_geometry(float(claw.area), float(claw.alpha), base_r)
	var gone := clampf(gone_mm, 0.0, reach)
	var area := 0.0
	var vol := 0.0
	var solid := 0.0
	var inner := 0.0
	var d0 := 0.0
	var r0 := 0.0
	for i in SHEATH_STEPS:
		var d1 := cover_mm * float(i + 1) / float(SHEATH_STEPS)
		var r1 := Contact.hole_radius(tip, d1)
		# el tramo de la punta que falta (macizo) y el que va sobre el muñón (hueco, pegado), partido donde se rompió
		var cut := clampf(gone, d0, d1)
		var rc := r0 + (r1 - r0) * ((cut - d0) / (d1 - d0)) if d1 > d0 else r1
		for seg: Array in [[d0, cut, r0, rc, true], [cut, d1, rc, r1, false]]:
			var dd := float(seg[1]) - float(seg[0])
			if dd <= 0.0:
				continue
			var dr := float(seg[3]) - float(seg[2])
			var rm := 0.5 * (float(seg[2]) + float(seg[3]))
			if bool(seg[4]):
				var v_solid := PI * (rm + wall_mm) * (rm + wall_mm) * dd
				vol += v_solid
				solid += v_solid
			else:
				area += 2.0 * PI * rm * sqrt(dd * dd + dr * dr)
				vol += PI * ((rm + wall_mm) * (rm + wall_mm) - rm * rm) * dd
				inner += PI * rm * rm * dd
		d0 = d1
		r0 = r1
	# la punta de la funda: un tapón macizo del espesor de la pared delante del vértice de la garra
	vol += PI * wall_mm * wall_mm * wall_mm
	var r_out := r0 + wall_mm
	var length := cover_mm + wall_mm
	# la queratina que queda: la del cono de ClawMass (la masa del banco) por la parte del perfil que no falta (lo que falta,
	# desde la punta hasta gone, cubra o no la funda)
	var ker := ClawMass.cone_volume_mm3(reach, base_r)
	if gone > 0.0:
		var whole := 0.0
		var missing := 0.0
		var e0 := 0.0
		var q0 := 0.0
		for i in SHEATH_STEPS:
			var e1 := reach * float(i + 1) / float(SHEATH_STEPS)
			var q1 := Contact.hole_radius(tip, e1)
			var qm := 0.5 * (q0 + q1)
			whole += PI * qm * qm * (e1 - e0)
			missing += PI * qm * qm * maxf(minf(e1, gone) - e0, 0.0)
			e0 = e1
			q0 = q1
		ker *= clampf(1.0 - missing / whole, 0.0, 1.0) if whole > 0.0 else 1.0
	return {
		"coverMm": cover_mm, "wallMm": wall_mm, "lengthMm": length, "innerAreaMm2": area, "volumeMm3": vol,
		"outerRadiusMm": r_out, "rawDiameterMm": 2.0 * r_out, "rawVolumeMm3": PI * r_out * r_out * length,
		"keratinVolumeMm3": ker, "naturalMm": reach, "goneMm": gone, "stumpCoverMm": maxf(cover_mm - gone, 0.0),
		"solidVolumeMm3": solid, "innerVolumeMm3": inner,
	}


## Calentar la superficie de la garra viva: la conducción en una dimensión por la barrera, la queratina (wall_mm hasta la
## carne viva) y el tejido vivo (con la sangre a la temperatura de partida detrás), con la superficie a t_surface_c durante
## time_s (implícito, como el modelo térmico de ClawCare; mismos datos de la queratina). Una barrera de gel se queda a
## 100 °C mientras le queda agua (se la lleva el calor de vaporización).
## { keratinPeakC (la cara de la queratina bajo la barrera), quickPeakC, charred (≥ CareData.THERMAL.char_c), pain (≥ el
##   umbral), injuryDose, injured, barrierFails (pasa de lo que aguanta), waterLeft (fracción) }.
static func barrier_heating(t_surface_c: float, time_s: float, barrier_id: String, barrier_mm: float, wall_mm: float) -> Dictionary:
	var bed: float = CareData.THERMAL.bed_c.value
	var b: Dictionary = ForgeData.BARRIERS.get(barrier_id, {})
	var bmm := barrier_mm if not b.is_empty() else 0.0
	if bmm > 0.0 and t_surface_c > float(b.max_c):
		# la barrera no aguanta esa temperatura: se descompone y la superficie caliente toca la queratina
		var bare := barrier_heating(t_surface_c, time_s, "", 0.0, wall_mm)
		bare["barrierFails"] = true
		bare["barrierMm"] = bmm
		return bare
	var k_ker := ClawCare.keratin_conductivity()
	var rc_ker: float = CareData.KERATIN_DENSITY * float(CareData.THERMAL.specific_heat_j_kg_k.value)
	var n_b := maxi(int(ceil(bmm / SLAB_DX_MM - 1e-9)), 2) if bmm > 0.0 else 0
	var n_k := maxi(int(ceil(wall_mm / SLAB_DX_MM - 1e-9)), 2)
	var n_l := maxi(int(round(float(CareData.THERMAL.live_mm.value) / SLAB_LIVE_DX_MM)), 2)
	# nodos: 0 = la superficie (temperatura impuesta); barrera; queratina; tejido vivo; último = la sangre (bed)
	var n := 1 + n_b + n_k + n_l + 1
	var dx := PackedFloat64Array()
	var kk := PackedFloat64Array()
	var rc := PackedFloat64Array()
	var water := PackedFloat64Array()
	dx.resize(n)
	kk.resize(n)
	rc.resize(n)
	water.resize(n)
	for i in n:
		if i == 0:
			dx[i] = 0.0
			kk[i] = float(b.k) if n_b > 0 else k_ker
			rc[i] = 0.0
		elif i <= n_b:
			dx[i] = bmm / float(n_b) / 1000.0
			kk[i] = float(b.k)
			rc[i] = float(b.rho) * float(b.cp)
			water[i] = float(b.rho) * float(b.get("water", 0.0)) * dx[i]
		elif i <= n_b + n_k:
			dx[i] = wall_mm / float(n_k) / 1000.0
			kk[i] = k_ker
			rc[i] = rc_ker
		else:
			dx[i] = SLAB_LIVE_DX_MM / 1000.0
			kk[i] = k_ker
			rc[i] = rc_ker
	var i_face := n_b + 1
	var i_quick := n_b + n_k
	var th := PackedFloat64Array()
	th.resize(n)
	for i in n:
		th[i] = bed
	th[0] = t_surface_c
	var g := PackedFloat64Array()  # conductancia por unidad de área entre i e i+1 (W/(m²·K))
	g.resize(n)
	for i in range(n - 1):
		var r_half := (dx[i] * 0.5 / kk[i] if dx[i] > 0.0 else 0.0) + (dx[i + 1] * 0.5 / kk[i + 1] if dx[i + 1] > 0.0 else 0.0)
		g[i] = 1.0 / r_half if r_half > 0.0 else 0.0
	var steps := clampi(int(ceil(time_s / 0.05)), SLAB_STEPS_MIN, SLAB_STEPS_MAX) if time_s > 0.0 else 0
	var dt := time_s / float(steps) if steps > 0 else 0.0
	var cp := PackedFloat64Array()
	var dp := PackedFloat64Array()
	cp.resize(n)
	dp.resize(n)
	var w0 := 0.0
	for i in n:
		w0 += water[i]
	var latent := float(b.get("latent_j_kg", 0.0))
	var boil := float(b.get("boil_c", INF))
	var face_peak := bed
	var quick_peak := bed
	var dose := 0.0
	for s in steps:
		# Euler implícito (algoritmo de Thomas) en los nodos interiores 1..n-2; 0 y n-1 impuestos
		for i in range(1, n - 1):
			var cdt := rc[i] * dx[i] / dt
			var bb := cdt + g[i - 1] + g[i]
			var d := cdt * th[i]
			var c_hi := g[i]
			if i == 1:
				d += g[0] * th[0]
			if i == n - 2:
				d += g[i] * bed
				c_hi = 0.0
			if i == 1:
				cp[i] = -c_hi / bb
				dp[i] = d / bb
			else:
				var den := bb + g[i - 1] * cp[i - 1]
				cp[i] = -c_hi / den
				dp[i] = (d + g[i - 1] * dp[i - 1]) / den
		th[n - 2] = dp[n - 2]
		for i in range(n - 3, 0, -1):
			th[i] = dp[i] - cp[i] * th[i + 1]
		# el agua del gel se evapora: el calor que la pasaría de 100 °C se la lleva
		if latent > 0.0:
			for i in range(1, n_b + 1):
				if water[i] > 0.0 and th[i] > boil:
					var excess := rc[i] * dx[i] * (th[i] - boil)
					var m := minf(excess / latent, water[i])
					water[i] -= m
					th[i] = boil + (excess - m * latent) / (rc[i] * dx[i])
		face_peak = maxf(face_peak, th[i_face])
		quick_peak = maxf(quick_peak, th[i_quick])
		var ti := ClawCare.injury_time_s(th[i_quick])
		if is_finite(ti):
			dose = minf(dose + dt / ti, ClawCare.DOSE_CAP)
	if n_b == 0:
		# sin barrera, la superficie caliente es la propia queratina
		face_peak = maxf(face_peak, t_surface_c)
	var w1 := 0.0
	for i in n:
		w1 += water[i]
	var char_c: float = CareData.THERMAL.char_c.value
	return {
		"keratinPeakC": face_peak, "quickPeakC": quick_peak, "charred": face_peak >= char_c, "charC": char_c,
		"pain": quick_peak >= float(CareData.THERMAL.pain_c.value), "injuryDose": dose, "injured": dose >= 1.0,
		"barrierFails": false, "waterLeft": w1 / w0 if w0 > 0.0 else 0.0,
		"barrierMm": bmm, "wallMm": wall_mm,
	}


# ════════════════════════════════ Etapa 1 · material ════════════════════════════════

## Pesa los polvos de la receta: { id del polvo: gramos }. Devuelve { ok, total, fractions, problems [{ powder, code, text }],
## defect, text }. Sin receta: { ok: false }.
func mix(grams: Dictionary) -> Dictionary:
	_mix = grams.duplicate(true)
	_mix_eval = evaluate_mix(_recipe, _mix)
	_serial += 1
	return _mix_eval.duplicate(true)


## Evalúa una mezcla contra una receta (estática, para la interfaz y los tests).
static func evaluate_mix(rec: Dictionary, grams: Dictionary) -> Dictionary:
	var out := { "ok": false, "total": 0.0, "fractions": {}, "problems": [], "defect": "", "text": "" }
	if rec.is_empty():
		out["defect"] = "receta"
		out["text"] = "Elige primero qué material quieres hacer."
		return out
	var total := 0.0
	for k: String in grams:
		total += maxf(float(grams[k]), 0.0)
	out["total"] = total
	if total <= 0.0:
		out["defect"] = "mezcla"
		out["text"] = "El crisol está vacío."
		out["problems"].append({ "powder": "", "code": "mezcla", "text": "El crisol está vacío.", "finish": "defectuoso" })
		return out
	var known := {}
	for p: Dictionary in rec.powders:
		known[p.id] = true
		var f := maxf(float(grams.get(p.id, 0.0)), 0.0) / total
		out.fractions[p.id] = f
		if f < float(p.min) - 1e-9:
			var lo: Dictionary = p.get("low", { "code": "mezcla", "text": "Falta %s." % String(ForgeData.POWDERS[p.id].name).to_lower() })
			out.problems.append({ "powder": p.id, "code": lo.code, "text": lo.text, "finish": String(lo.get("finish", "defectuoso")) })
		elif f > float(p.max) + 1e-9:
			var hi: Dictionary = p.get("high", { "code": "mezcla", "text": "Sobra %s: los demás quedan por debajo de la receta." % String(ForgeData.POWDERS[p.id].name).to_lower() })
			out.problems.append({ "powder": p.id, "code": hi.code, "text": hi.text, "finish": String(hi.get("finish", "defectuoso")) })
	for k: String in grams:
		if not known.has(k) and float(grams[k]) > 0.0:
			out.fractions[k] = float(grams[k]) / total
			var nm := String(ForgeData.POWDERS[k].name) if ForgeData.POWDERS.has(k) else k
			out.problems.append({ "powder": k, "code": "mezcla", "text": "%s no va en esta receta: contamina el material." % nm, "finish": "defectuoso" })
	out["ok"] = (out.problems as Array).is_empty()
	if not out.ok:
		out["defect"] = String(out.problems[0].code)
		out["text"] = String(out.problems[0].text)
		out["finish"] = String(out.problems[0].finish)
	return out


## Una pieza comprada (gemas y minerales naturales o de fábrica, o un bloque de metal): un bloque del que se talla la funda.
func choose(material_id: String) -> Dictionary:
	var e: Variant = ForgeData.inlay_entry(material_id)
	if e == null or material_id == "none":
		return { "ok": false, "text": "Ese material no existe." }
	var m := ForgeData.material(material_id)
	_piece = {
		"ok": true, "material": material_id, "variety": "", "form": "bloque", "tempC": ROOM_C, "defect": "", "text": String(m.get("route_text", "")),
		"rawVolumeMm3": float(_sheath.rawVolumeMm3), "sizeMm": float(_sheath.lengthMm), "quality": "secondary", "source": String(m.get("route_text", "")),
		"bought": true, "finish": "bruto",
	}
	_fire = {}
	_cooled = { "ok": true, "medium": "", "text": "Pieza a temperatura ambiente." }
	_carved = {}
	_coat = {}
	_bond = {}
	_polish = {}
	_surf = {}
	_check = {}
	_loaded = {}
	_mold_in = false
	_wax = {}
	_invest = {}
	_burnout = {}
	_divest = {}
	_cut = {}
	_fit = {}
	_weld = {}
	_fiction = []
	_event("comprar", String(_piece.text), String(_piece.source))
	_serial += 1
	return _piece.duplicate(true)


# ════════════════════════════════ La carga dentro de su máquina (5m) ════════════════════════════════

## Lo que entra en cada máquina (ForgeData.MACHINES): «alimentador» (la tolva de Verneuil), «capsula», «sustrato», «pastilla»
## o «crisol»; en el horno de calentar, la pieza (o el molde de la cera perdida, para quemarla).
static func charge_for(machine: String) -> String:
	return String((ForgeData.MACHINES.get(machine, {}) as Dictionary).get("charge", "crisol"))


## Mete la carga en su máquina y la cierra (petición 42). Es procedimiento: la interfaz no arranca sin la carga dentro de la
## máquina del modo; fire() no lo exige (las llamadas directas de otras unidades y de los tests siguen igual). p { machine
## (ForgeData.MACHINES), what (lo que entra; por defecto, lo de esa máquina: charge_for) }. «molde»: el molde revestido de la
## cera perdida, que se queda en el horno del quemado a la colada. { ok, machine, what, name, text, defect, source }.
func load_machine(p: Dictionary) -> Dictionary:
	var mid := String(p.get("machine", ""))
	var what := String(p.get("what", charge_for(mid)))
	var m: Dictionary = ForgeData.MACHINES.get(mid, {})
	var out := { "ok": false, "machine": mid, "what": what, "name": String(m.get("name", "")), "text": "", "defect": "", "source": String(m.get("source", "")) }
	if m.is_empty():
		out["defect"] = "maquina"
		out["text"] = "Esa máquina no existe."
	elif what == "molde":
		if not bool(_invest.get("ok", false)):
			out["defect"] = "sin_molde"
			out["text"] = "No hay molde que meter: primero el modelo de cera de la garra y su revestimiento."
		elif mid != "calentar" and not bool(_burnout.get("ok", false)):
			out["defect"] = "maquina"
			out["text"] = "El molde se mete en el horno de calentar para quemar la cera: pon el modo «Calentar»."
	elif what == "pieza":
		if _piece.is_empty() or not bool(_piece.get("ok", false)):
			out["defect"] = "sin_pieza"
			out["text"] = "No hay pieza buena que meter en el horno."
	elif _mix_eval.is_empty():
		out["defect"] = "vacio"
		out["text"] = "El crisol está vacío: pesa los polvos y cárgalos primero."
	if out.defect == "":
		out["ok"] = true
		if what == "molde":
			_mold_in = true
		else:
			_loaded = { "machine": mid, "what": what }
		var nm := String(ForgeData.CHARGE_NAMES.get(what, what))
		out["text"] = "%s, en %s: %s; %s." % [nm.substr(0, 1).to_upper() + nm.substr(1), String(m.name).to_lower(), String(m.where), String(m.close)] if what == charge_for(mid) else "%s, en %s; %s." % [nm.substr(0, 1).to_upper() + nm.substr(1), String(m.name).to_lower(), String(m.close)]
	_event("cargar_" + ("ok" if out.ok else String(out.defect)), String(out.text), String(out.source))
	_serial += 1
	return out


## Lo que hay metido en las máquinas: { machine, what, moldIn } (machine «» si no hay nada).
func loaded() -> Dictionary:
	return { "machine": String(_loaded.get("machine", "")), "what": String(_loaded.get("what", "")), "moldIn": _mold_in }


# ════════════════════════════════ Etapa 2 · horno ════════════════════════════════

## Enciende el horno con la receta y la mezcla: p { mode, temp_c, time_s, atmosphere, pressure_mpa, mold, methane (CVD,
## fracción de CH₄) }. Devuelve { ok, defect, text, problems [{ param, code, text }], piece, need (lo que hacía falta crecer),
## grown, timeNeedS, tMaxC (el límite de temperatura que aplica) }.
func fire(p: Dictionary) -> Dictionary:
	var pp := p.duplicate(true)
	# con la cera perdida, la colada va al molde que se revistió (5m)
	if _lost_wax() and bool(_invest.get("ok", false)):
		pp["mold"] = String(_invest.mold)
	var out := evaluate_fire(_recipe, _mix_eval, pp, _sheath)
	if String(_recipe.get("form", "")) == "colada":
		_cast_checks(out)
	_fire = out
	_piece = (out.piece as Dictionary).duplicate(true)
	_cooled = {}
	_carved = {}
	_coat = {}
	_bond = {}
	_polish = {}
	_surf = {}
	_check = {}
	_cut = {}
	_fit = {}
	_weld = {}
	_divest = {}
	_fiction = []
	# lo que había en la máquina ya es la pieza, y sigue dentro hasta que se saca a enfriar
	if not _loaded.is_empty():
		_loaded = { "machine": String(_loaded.machine), "what": "pieza" }
	if out.ok:
		_event("horno_ok", "Sale %s." % String(_piece.get("variety", "")) if String(_piece.get("variety", "")) != "" else "La pieza sale bien.", String(_recipe.source))
	else:
		_event("horno_" + String(out.defect), String(out.text), String(_recipe.source))
	_serial += 1
	return out.duplicate(true)


## Evaluación del horno (estática): la receta, la mezcla evaluada, los parámetros y la funda que hay que sacar.
static func evaluate_fire(rec: Dictionary, mix_eval: Dictionary, p: Dictionary, sh: Dictionary) -> Dictionary:
	var out := { "ok": false, "defect": "", "text": "", "problems": [], "piece": {}, "need": 0.0, "grown": 0.0, "timeNeedS": 0.0, "tMaxC": INF, "pMinMPa": 0.0, "params": p.duplicate(true) }
	if rec.is_empty():
		out["defect"] = "receta"
		out["text"] = "Elige primero qué material quieres hacer."
		return out
	var probs: Array = out.problems
	var mode := String(p.get("mode", ""))
	var t := float(p.get("temp_c", ROOM_C))
	var time := maxf(float(p.get("time_s", 0.0)), 0.0)
	var atm := String(p.get("atmosphere", "aire"))
	var pr := maxf(float(p.get("pressure_mpa", 0.101)), 0.0)
	var prod := String(rec.product)
	var mat := ForgeData.material(prod)
	# 1. modo
	if mode != String(rec.mode):
		probs.append(_prob("mode", { "code": "modo", "text": "Así no se hace: %s" % String(mat.get("route_text", "")) }))
	# 2. mezcla (y el metano de la CVD)
	if mix_eval.is_empty() or not bool(mix_eval.get("ok", false)):
		var txt := String(mix_eval.get("text", "")) if not mix_eval.is_empty() else "No has cargado la mezcla de la receta."
		probs.append(_prob("mix", { "code": "mezcla", "text": txt if txt != "" else "La mezcla no es la de la receta.", "finish": String(mix_eval.get("finish", "defectuoso")) }))
	if rec.has("methane"):
		var me: Dictionary = rec.methane
		var ch4 := float(p.get("methane", me.value))
		if ch4 < float(me.min) - 1e-12:
			probs.append(_prob("methane", me.low))
		elif ch4 > float(me.max) + 1e-12:
			probs.append(_prob("methane", me.high))
	# 3. atmósfera
	var at: Dictionary = rec.atmosphere
	if not (at.ok as Array).has(atm):
		var bad: Dictionary = (at.bad as Dictionary).get(atm, { "code": "atmosfera", "text": "Esa atmósfera no es la de la receta." })
		probs.append(_prob("atmosphere", bad))
	# 4. presión (y la línea de Kennedy en el diamante HPHT)
	var pd: Dictionary = rec.pressure_mpa
	var t_max := float(rec.temp_c.max)
	if String(rec.method) == "hpht":
		var p_min := kennedy_mpa(t)
		out["pMinMPa"] = p_min
		t_max = minf(t_max, kennedy_t_max(pr))
		if pr < p_min and pr < float(pd.value) - 1e-9:
			probs.append(_prob("pressure_mpa", pd.low))
		elif pr > float(pd.max):
			probs.append(_prob("pressure_mpa", { "code": "presion", "text": "La prensa no da más de %s GPa." % Js.to_fixed(float(pd.max) / 1000.0, 0) }))
	else:
		if pd.has("high") and pr > float(pd.max):
			probs.append(_prob("pressure_mpa", pd.high))
	out["tMaxC"] = t_max
	# 5. temperatura
	var td: Dictionary = rec.temp_c
	if t < float(td.min):
		probs.append(_prob("temp_c", td.low))
	elif t > t_max:
		probs.append(_prob("temp_c", td.high))
	# 6. tiempo y tamaño: lo que crece contra lo que pide la funda
	var tm: Dictionary = rec.time_s
	var need_t := float(tm.min)
	var grown := 0.0
	var need := 0.0
	var size_ok := true
	var size_text := ""
	var gr: Dictionary = rec.get("growth", {})
	if not gr.is_empty():
		match String(gr.kind):
			"mm_h":
				need = float(sh.lengthMm)
				need_t = need / float(gr.value) * 3600.0
				grown = float(gr.value) * time / 3600.0
				if float(sh.rawDiameterMm) > float(gr.max_diameter_mm):
					size_ok = false
					size_text = "La funda pide un cristal de %s mm de diámetro y una bola de Verneuil no pasa de %s mm: esta garra es demasiado gruesa para este método (la industria usaría Kyropoulos o Czochralski)." % [Js.to_fixed(float(sh.rawDiameterMm), 1), Js.to_fixed(float(gr.max_diameter_mm), 0)]
			"mg_h":
				var rho: float = ForgeData.density_of(prod)
				need = rho * float(sh.rawVolumeMm3) * 1.0e-9 * 1.0e6  # mg
				need_t = need / float(gr.value) * 3600.0
				grown = float(gr.value) * time / 3600.0
				if float(sh.rawDiameterMm) > float(gr.max_diameter_mm):
					size_ok = false
					size_text = "La funda pide un cristal de %s mm y los cristales HPHT de calidad de Sumiya y sus colegas (2002) llegaban a ~%s mm: cubre menos garra." % [Js.to_fixed(float(sh.rawDiameterMm), 1), Js.to_fixed(float(gr.max_diameter_mm), 0)]
			"um_h":
				need = float(sh.wallMm) * 1000.0
				need_t = need / float(gr.value) * 3600.0
				grown = float(gr.value) * time / 3600.0
	elif String(rec.id) == "alumina":
		need_t = alumina_time_s(t)
	out["need"] = need
	out["grown"] = grown
	out["timeNeedS"] = need_t
	if time + 1e-9 < need_t:
		probs.append(_prob("time_s", tm.low))
	# 7. molde
	if rec.has("mold"):
		var md: Dictionary = rec.mold
		var mold := String(p.get("mold", md.value))
		if not (md.ok as Array).has(mold):
			var bad_m: Dictionary = (md.bad as Dictionary).get(mold, { "code": "molde", "text": "Ese molde no sirve para esta colada." })
			probs.append(_prob("mold", bad_m))
	if not size_ok:
		probs.append(_prob("size", { "code": "tamano", "text": size_text }))
	out["ok"] = probs.is_empty()
	if not out.ok:
		out["defect"] = String(probs[0].code)
		out["text"] = String(probs[0].text)
	else:
		out["text"] = "Sale %s: listo para enfriar." % (String(rec.variety) if String(rec.variety) != "" else String(ForgeData.inlay_entry(prod).name).to_lower())
	var raw := float(sh.rawVolumeMm3)
	var size := float(sh.lengthMm)
	match String(rec.form):
		"bola":
			size = grown
		"cristal":
			size = grown  # mg
		"capa":
			size = grown  # µm
	out["piece"] = {
		"ok": out.ok, "material": prod, "variety": String(rec.variety), "form": String(rec.form), "tempC": t, "defect": out.defect,
		"text": out.text, "rawVolumeMm3": raw, "sizeMm": size, "quality": String(rec.quality), "source": String(rec.source),
		"recipe": String(rec.id), "bought": false, "finish": "bruto" if out.ok else String(probs[0].finish),
	}
	return out


## Un problema del horno: { param, code, text, finish } con el acabado que dice la receta («defectuoso» si no lo dice).
static func _prob(param: String, d: Dictionary) -> Dictionary:
	return { "param": param, "code": String(d.code), "text": String(d.text), "finish": String(d.get("finish", "defectuoso")) }


## Calentar una pieza (modo «calentar»): p { temp_c, time_s, atmosphere }. Qué le hace el calor según sus datos: se funde,
## se reblandece, se oxida o se quema, se grafitiza, cruza la inversión del cuarzo. { ok, state (heat_state), defect, text }.
func heat(p: Dictionary) -> Dictionary:
	var out := { "ok": false, "defect": "", "text": "", "state": {} }
	if _piece.is_empty() or not bool(_piece.get("ok", false)):
		out["defect"] = "sin_pieza"
		out["text"] = "No hay pieza que calentar."
		return out
	var t := float(p.get("temp_c", ROOM_C))
	var atm := String(p.get("atmosphere", "aire"))
	var mid := String(_piece.material)
	var m := ForgeData.material(mid)
	var st := heat_state(mid, t, atm)
	out["state"] = st
	out["ok"] = true
	if bool(st.noData):
		out["text"] = "Sin datos de lo que el calor le hace a este material: no se predice."
	elif bool(st.melted):
		out["ok"] = false
		out["defect"] = "funde"
		out["text"] = "Pasa de su punto de fusión (%s °C): la pieza se funde y pierde la forma." % Js.to_fixed(float(m.melt_c.value), 0)
	elif bool(st.softened):
		out["ok"] = false
		out["defect"] = "reblandece"
		var what := "el acrílico se ablanda" if String(m.family) == "polimero" else "el vidrio se comba"
		out["text"] = "Pasa de su reblandecimiento (%s °C): %s y pierde la forma." % [Js.to_fixed(float(m.soften_c.value), 0), what]
	elif bool(st.oxidized):
		var ruin: bool = String(m.family) != "metal"
		out["ok"] = not ruin
		out["defect"] = "quemado" if ruin else "cascarilla"
		out["text"] = "Al aire por encima de %s °C %s." % [Js.to_fixed(float(m.air_c.value), 0), String(m.air_what)]
	elif bool(st.graphitized):
		out["ok"] = false
		out["defect"] = "grafitiza"
		out["text"] = "Por encima de ~%s °C, aun sin aire, el diamante se vuelve grafito." % Js.to_fixed(float(m.inert_c.value), 0)
	else:
		out["text"] = "No le pasa nada a %s °C." % Js.to_fixed(t, 0)
	if bool(st.inversion) and out.ok:
		out["text"] = String(out.text) + " Ha cruzado los %s °C del cuarzo: hay que enfriarlo dentro del horno." % Js.to_fixed(float(m.inversion_c.value), 0)
	if out.ok:
		_piece["tempC"] = t
		_cooled = {}
		if out.defect == "cascarilla":
			_piece["finish"] = "oxidado"
	else:
		_piece["ok"] = false
		_piece["defect"] = out.defect
		_piece["text"] = out.text
		_piece["finish"] = "quemado" if String(out.defect) in ["quemado", "grafitiza"] else "defectuoso"
	_event("calentar_" + (String(out.defect) if out.defect != "" else "ok"), String(out.text), _material_source(mid))
	_serial += 1
	return out


func _material_source(mid: String) -> String:
	var m := ForgeData.material(mid)
	for key: String in ["melt_c", "soften_c", "air_c", "inert_c", "inversion_c"]:
		if m.get(key) != null:
			return String(m[key].source)
	return String(m.get("route_text", ""))


# ════════════════════════════════ Etapa 2b · la cera perdida (5m) ════════════════════════════════

## ¿Va a la cera perdida? Una receta de colada (los metales y el vidrio) con su modelo de cera hecho.
func _lost_wax() -> bool:
	return String(_recipe.get("form", "")) == "colada" and bool(_wax.get("ok", false))


## ¿Se cuela en un molde con la forma de la garra? Los metales y el vidrio de las recetas de colada, sí; los minerales duros no
## se cuelan en un taller, y el texto dice por qué (ForgeData.NO_CAST). material_id: el de una piedra comprada (sin receta).
## { ok, text, source }.
static func castable(rec: Dictionary, material_id: String = "") -> Dictionary:
	if material_id == "" and not rec.is_empty() and String(rec.get("form", "")) == "colada" and ForgeData.CAST.has(String(rec.product)):
		return { "ok": true, "text": "", "source": String(ForgeData.CAST[String(rec.product)].shrink.source) }
	var mid := material_id if material_id != "" else String(rec.get("product", ""))
	var txt := String(ForgeData.NO_CAST.get(mid, "Este material no se cuela en un molde de taller: se talla."))
	return { "ok": false, "text": txt, "source": ForgeData.NO_CAST_SOURCE }


## El revestimiento de ese molde para ese material (ForgeData.INVESTMENTS; el del vidrio, el de yeso y sílice de Bullseye).
static func investment_of(mold: String, product: String) -> Dictionary:
	if product == "vidrio" and mold == "yeso":
		return ForgeData.GLASS_INVESTMENT
	return ForgeData.INVESTMENTS.get(mold, ForgeData.INVESTMENTS.yeso)


## El diámetro del bebedero (mm): tiene que solidificar después de lo más grueso de la pieza para alimentarla mientras encoge
## (la regla de Chvorinov; Campbell: su módulo, d/4, 1,2 veces el de la pieza). Lo más grueso es la pared (una placa: t/2) o,
## en una prótesis que rehace maciza la punta que falta, ese tramo macizo (un cilindro: su radio medio entre 2).
static func sprue_diameter_mm(sh: Dictionary) -> float:
	var m := 0.5 * float(sh.wallMm)
	var l := minf(float(sh.get("goneMm", 0.0)), float(sh.coverMm))
	if l > 0.0 and float(sh.get("solidVolumeMm3", 0.0)) > 0.0:
		m = maxf(m, 0.5 * sqrt(float(sh.solidVolumeMm3) / (PI * l)))
	return 4.0 * float(ForgeData.SPRUE.modulus_factor.value) * m


## Un porcentaje legible con dos decimales: «1.67».
static func _pct2(f: float) -> String:
	return Js.to_fixed(f * 100.0, 2)


## El modelo de cera de la funda, con la forma de la garra de su dedo (CareData.claw_shape: la misma funda de sheath_geometry), y
## su bebedero (5m). p { compensate (por defecto, sí: la cera se hace más grande lo que encoge el material y no compensa el
## revestimiento; ForgeData.CAST e INVESTMENTS), mold (el revestimiento para el que se hace; por defecto, el de la receta) }.
## { ok, defect, text, compensate, scale (la de la cera frente a la funda), shrink, expansion, mold, sprueDiameterMm,
##   sprueLengthMm, waxVolumeMm3, metalG (lo que hace falta del material para llenarla con su bebedero), source }.
func wax(p: Dictionary = {}) -> Dictionary:
	var c := castable(_recipe)
	var out := { "ok": false, "defect": "", "text": "", "compensate": bool(p.get("compensate", true)), "scale": 1.0, "shrink": 0.0,
		"expansion": 0.0, "mold": "", "sprueDiameterMm": 0.0, "sprueLengthMm": 0.0, "waxVolumeMm3": 0.0, "metalG": 0.0, "source": String(c.source) }
	if not bool(c.ok):
		out["defect"] = "no_se_cuela"
		out["text"] = String(c.text) if not _recipe.is_empty() else "Elige primero un metal o el vidrio: es lo que se cuela."
	else:
		var prod := String(_recipe.product)
		var mold := String(p.get("mold", _recipe.mold.value))
		var inv := investment_of(mold, prod)
		var shrink := float(ForgeData.CAST[prod].shrink.value)
		var expn := float(inv.expansion.value)
		var scale := 1.0 / ((1.0 + expn) * (1.0 - shrink)) if bool(out.compensate) else 1.0
		var d := sprue_diameter_mm(_sheath)
		var L := float(ForgeData.SPRUE.length_mm.value)
		var v_wax := float(_sheath.volumeMm3) * scale * scale * scale + 0.25 * PI * d * d * L
		var rho: float = ForgeData.density_of(prod)
		out.merge({ "ok": true, "scale": scale, "shrink": shrink, "expansion": expn, "mold": mold, "sprueDiameterMm": d, "sprueLengthMm": L,
			"waxVolumeMm3": v_wax, "metalG": rho * v_wax * 1.0e-6,
			"source": String(ForgeData.CAST[prod].shrink.source) + "; " + String(inv.expansion.source) + "; " + ForgeData.SRC_CAMPBELL }, true)
		var nm := String(ForgeData.inlay_entry(prod).name).to_lower()
		var size := "Hecha un %s %% más grande: el %s encoge un %s %% al colarse y el revestimiento se dilata un %s %%." % [_pct2(scale - 1.0), nm, _pct2(shrink), _pct2(expn)] if bool(out.compensate) else "A la medida de la funda, sin compensar: el %s encogerá un %s %% y el revestimiento se dilatará un %s %%." % [nm, _pct2(shrink), _pct2(expn)]
		out["text"] = "Modelo de cera de la funda de la garra (%s mm de largo y %s mm de pared) con su bebedero de Ø %s mm, más grueso que la pared para que solidifique el último y la alimente mientras encoge. %s" % [Js.to_fixed(float(_sheath.lengthMm), 1), Js.to_fixed(_wall_mm, 2), Js.to_fixed(d, 1), size]
	_wax = out
	_invest = {}
	_burnout = {}
	_mold_in = false
	_event("cera_" + ("ok" if out.ok else String(out.defect)), String(out.text), String(out.source))
	_serial += 1
	return out.duplicate(true)


## Reviste el modelo de cera (5m): p { mold («yeso», «ceramico» o «grafito»; por defecto, para el que se hizo la cera) }. El
## grafito no se reviste: se mecaniza un molde partido con la forma. { ok, defect, text, mold, name, expansion, setS (lo que
## fragua de verdad antes de quemarlo), machined, warning (el molde que no aguanta este material: lo dirá la colada), source }.
func invest(p: Dictionary = {}) -> Dictionary:
	var mold := String(p.get("mold", String(_wax.get("mold", "yeso"))))
	var out := { "ok": false, "defect": "", "text": "", "mold": mold, "name": "", "expansion": 0.0, "setS": 0.0, "machined": false, "warning": "", "source": "" }
	if not bool(_wax.get("ok", false)):
		out["defect"] = "sin_cera"
		out["text"] = "Primero el modelo de cera de la garra."
	elif not ForgeData.INVESTMENTS.has(mold):
		out["defect"] = "molde"
		out["text"] = "Ese molde no existe."
	else:
		var prod := String(_recipe.product)
		var inv := investment_of(mold, prod)
		out.merge({ "ok": true, "name": String(inv.name), "expansion": float(inv.expansion.value), "setS": float(inv.set_s.value),
			"machined": bool(inv.machined), "source": String(inv.expansion.source) + "; " + String(inv.set_s.source) }, true)
		var md: Dictionary = _recipe.get("mold", {})
		if not md.is_empty() and not (md.ok as Array).has(mold):
			out["warning"] = String(((md.bad as Dictionary).get(mold, {}) as Dictionary).get("text", "Ese molde no sirve para esta colada."))
		var nm := String(ForgeData.inlay_entry(prod).name).to_lower()
		if bool(out.machined):
			out["text"] = "El grafito no se reviste: se mecaniza un molde partido con la forma de la funda, más grande lo que encoge el %s, y no hay cera que quemar." % nm
		else:
			out["text"] = "%s alrededor de la cera, con el bebedero hacia fuera: fragua %s antes de quemarlo y se dilata un %s %%, lo que compensa lo que encoge el %s." % [String(inv.name), fmt_time(float(out.setS)), _pct2(float(out.expansion)), nm]
		if String(out.warning) != "":
			out["text"] = String(out.text) + " Ojo: " + String(out.warning)
	_invest = out
	_burnout = {}
	_mold_in = false
	_event("revestir_" + ("ok" if out.ok else String(out.defect)), String(out.text), String(out.source))
	_serial += 1
	return out.duplicate(true)


## El ciclo del quemado de la cera (5m): el de su revestimiento (ForgeData.BURNOUT; el vidrio, el de Bullseye) con la
## temperatura y el mantenimiento de arriba que se programan, y después hasta la temperatura del molde al colar ese material
## (ForgeData.MOLD_C) con la subida por defecto y 1 h para que el centro del molde llegue a ella (SRS). { steps [{ toC, rampS,
## holdS }], rampS, holdS, realS (todo), topC (el de la fuente), topMinC, topMaxC, topHoldS, moldC, name, quality, source };
## {} si ese molde no se quema (el grafito).
static func burnout_plan(mold: String, product: String, top_c: float, top_hold_s: float) -> Dictionary:
	var key := "vidrio" if product == "vidrio" and mold == "yeso" else mold
	var b: Dictionary = ForgeData.BURNOUT.get(key, {})
	if b.is_empty():
		return {}
	var rate := float(b.rate_c_s)
	var t := ROOM_C
	var steps: Array = []
	var ramp_sum := 0.0
	var hold_sum := 0.0
	for seg: Dictionary in b.segments:
		var to: float = top_c if seg.to is String else float(seg.to)
		var ramp: float = float(seg.ramp_s) if seg.has("ramp_s") else absf(to - t) / float(seg.get("rate_c_s", rate))
		var hold: float = top_hold_s if seg.hold_s is String else float(seg.hold_s)
		steps.append({ "toC": to, "rampS": ramp, "holdS": hold })
		ramp_sum += ramp
		hold_sum += hold
		t = to
	var mc: Dictionary = ForgeData.MOLD_C.get(product, {})
	var mold_c := float(mc.get("value", t))
	if key != "vidrio" and absf(mold_c - t) > 1e-9:
		var down := absf(mold_c - t) / rate
		steps.append({ "toC": mold_c, "rampS": down, "holdS": 3600.0 })
		ramp_sum += down
		hold_sum += 3600.0
	return {
		"steps": steps, "rampS": ramp_sum, "holdS": hold_sum, "realS": ramp_sum + hold_sum, "topC": float(b.top_c),
		"topMinC": float(b.top_min_c), "topMaxC": float(b.top_max_c), "topHoldS": float(b.top_hold_s), "moldC": mold_c if key != "vidrio" else t,
		"name": String(b.name), "quality": String(b.quality), "source": String(b.source) + ("; " + String(mc.source) if not mc.is_empty() else ""),
	}


## Quema la cera del molde en el horno (5m; con el molde dentro, en el modo de calentar): p { temp_c, time_s }, la temperatura y
## el mantenimiento de arriba del ciclo. Más frío o más corto de lo que pide el revestimiento, la cera no se quema del todo (la
## colada sale con poros y no llena: Kerr); el yeso por encima de ~816 °C se descompone (poros: Ganoksin) y el molde del vidrio
## por encima de ~843 °C falla (Bullseye). Después, el molde se queda caliente en el horno, a la temperatura de colada.
## { ok, defect, text, finish, realS (lo que tarda de verdad todo el ciclo), plan, moldC, tempC, timeS, source }.
func burnout(p: Dictionary) -> Dictionary:
	var top_c := float(p.get("temp_c", 0.0))
	var top_h := maxf(float(p.get("time_s", 0.0)), 0.0)
	var out := { "ok": false, "defect": "", "text": "", "finish": "", "realS": 0.0, "plan": {}, "moldC": ROOM_C, "tempC": top_c, "timeS": top_h, "source": "" }
	if not bool(_invest.get("ok", false)):
		out["defect"] = "sin_molde"
		out["text"] = "No hay molde revestido que quemar: primero el modelo de cera y su revestimiento."
	elif bool(_invest.get("machined", false)):
		out["ok"] = true
		out["moldC"] = top_c
		out["text"] = "El molde de grafito no lleva cera: solo se calienta con el horno."
		out["source"] = String(_invest.source)
	else:
		var prod := String(_recipe.product)
		var plan := burnout_plan(String(_invest.mold), prod, top_c, top_h)
		out["plan"] = plan
		out["realS"] = float(plan.realS)
		out["source"] = String(plan.source)
		if top_c < float(plan.topMinC) - 1e-9:
			out["defect"] = "cera_sin_quemar"
			out["finish"] = "poroso"
			out["text"] = "A %s la cera no se quema del todo (el ciclo pide %s arriba): el carbono que queda da poros y la colada no llena." % [_fmt_c(top_c), _fmt_c(float(plan.topMinC))]
		elif top_c > float(plan.topMaxC) + 1e-9:
			out["defect"] = "molde_quemado"
			out["finish"] = "poroso"
			out["text"] = ("A %s el yeso se descompone (no pasa de ~816 °C): suelta gases de azufre que manchan el metal y dan poros." % _fmt_c(top_c)) if prod != "vidrio" else ("Por encima de ~%s el molde de yeso y sílice se debilita y falla." % _fmt_c(float(plan.topMaxC)))
		elif top_h + 1e-9 < float(plan.topHoldS):
			out["defect"] = "cera_sin_quemar"
			out["finish"] = "poroso"
			out["text"] = "%s a %s es poco: el ciclo pide %s para quemar la cera del todo; lo que queda da poros y la colada no llena." % [fmt_time(top_h), _fmt_c(top_c), fmt_time(float(plan.topHoldS))]
		else:
			out["ok"] = true
			out["moldC"] = float(plan.moldC)
			out["text"] = "Cera quemada: %s de verdad (%s de mantenimientos y %s de subidas y bajadas). El molde se queda en el horno a %s para colar." % [fmt_time(float(plan.realS)), fmt_time(float(plan.holdS)), fmt_time(float(plan.rampS)), _fmt_c(float(plan.moldC))]
	_burnout = out
	_event("quemar_" + ("ok" if out.ok else String(out.defect)), String(out.text), String(out.source))
	_serial += 1
	return out.duplicate(true)


## La escala de la pieza colada frente a la funda de diseño (5m): la de la cera, por lo que se dilata el revestimiento y lo que
## encoge el material. 1 si la cera compensó el revestimiento en que se coló; 1 sin la cera perdida.
func cast_scale() -> float:
	if not _lost_wax() or not bool(_invest.get("ok", false)):
		return 1.0
	return float(_wax.scale) * (1.0 + float(_invest.expansion)) * (1.0 - float(_wax.shrink))


## La colada en el molde de la cera perdida (5m). Sin ella, el metal va a una lingotera y la funda se talla del lingote; con
## ella, la pieza sale con la forma de la garra y su bebedero, y con los defectos del molde (sin revestir, la cera sin quemar,
## poco material; Kerr). Añade sus problemas a out (manda el primero que salió) y la colada a la pieza.
func _cast_checks(out: Dictionary) -> void:
	var piece: Dictionary = out.piece
	if not _lost_wax():
		piece["form"] = "lingote"
		if bool(out.ok):
			out["text"] = String(out.text) + " Sin la cera perdida, el metal se cuela en una lingotera: la funda se talla del lingote."
			piece["text"] = out.text
		return
	var extra: Array = []
	if not bool(_invest.get("ok", false)):
		extra.append(_prob("mold", { "code": "sin_molde", "text": "La cera sin revestir se derrite al entrar el metal: no hay molde con la forma de la garra.", "finish": "defectuoso" }))
	elif not bool(_invest.get("machined", false)) and not bool(_burnout.get("ok", false)):
		if _burnout.is_empty():
			extra.append(_prob("burnout", { "code": "cera_sin_quemar", "text": "La cera sigue en el molde: el metal la quema al entrar, hierve, deja poros y no llena el molde.", "finish": "poroso" }))
		else:
			extra.append(_prob("burnout", { "code": String(_burnout.defect), "text": String(_burnout.text), "finish": String(_burnout.get("finish", "poroso")) }))
	var need := float(_wax.get("metalG", 0.0))
	var have := float(_mix_eval.get("total", 0.0))
	if bool(_mix_eval.get("ok", false)) and have + 1e-9 < need:
		extra.append(_prob("metal", { "code": "poco_metal", "text": "Falta material: el molde con su bebedero pide %s g y en el crisol hay %s g; la colada no llena." % [Js.to_fixed(need, 1), Js.to_fixed(have, 1)], "finish": "defectuoso" }))
	for e: Dictionary in extra:
		(out.problems as Array).append(e)
	if bool(out.ok) and not extra.is_empty():
		out["ok"] = false
		out["defect"] = String(extra[0].code)
		out["text"] = String(extra[0].text)
		piece["ok"] = false
		piece["defect"] = out.defect
		piece["text"] = out.text
		piece["finish"] = String(extra[0].finish)
	var scale := cast_scale()
	var misrun := String(out.defect) in ["frio", "poco_metal", "cera_sin_quemar", "sin_molde"]
	piece["form"] = "colada"
	piece["sprue"] = true
	piece["cast"] = {
		"scale": scale, "shrink": float(_wax.shrink), "expansion": float(_invest.get("expansion", 0.0)), "compensate": bool(_wax.compensate),
		"sprueDiameterMm": float(_wax.sprueDiameterMm), "sprueLengthMm": float(_wax.sprueLengthMm), "mold": String(_invest.get("mold", "")),
		"filled": float(ForgeData.SPRUE.misrun_fill.value) if misrun else 1.0,
	}
	if bool(out.ok):
		out["text"] = String(out.text) + " Cuela en el molde con la forma de la garra: encoge un %s %% al enfriarse, el revestimiento se dilata un %s %% y la pieza sale al %s %% de la funda de diseño." % [_pct2(float(_wax.shrink)), _pct2(float(_invest.get("expansion", 0.0))), Js.to_fixed(scale * 100.0, 2)]
		piece["text"] = out.text


## Rompe el molde y saca la pieza con su bebedero (5m): con la colada hecha en la cera perdida y ya fría (el vidrio, recocido).
## _p: sin ajustes (está para que el estado y los tests la llamen como las demás, con un diccionario). { ok, defect, text, realS
## (el vidrio, un día a la temperatura ambiente antes de desmoldar, Bullseye; el metal, unos minutos, sin cifra: 0),
## sprueDiameterMm, sprueLengthMm, source }.
func divest(_p: Dictionary = {}) -> Dictionary:
	var glass := String(_recipe.get("product", "")) == "vidrio"
	var out := { "ok": false, "defect": "", "text": "", "realS": 0.0, "sprueDiameterMm": 0.0, "sprueLengthMm": 0.0, "source": ForgeData.SRC_BULLSEYE_TS8 if glass else ForgeData.SRC_KERR }
	if _piece.is_empty() or not bool(_piece.get("sprue", false)):
		out["defect"] = "sin_colada"
		out["text"] = "No hay colada en un molde que romper."
	elif bool(_piece.get("divested", false)):
		out["defect"] = "hecho"
		out["text"] = "La pieza ya está fuera del molde."
	elif not bool(_piece.get("ok", false)) or not bool(_cooled.get("ok", false)):
		out["defect"] = "caliente"
		out["text"] = "Primero hay que sacar el molde y dejar que se enfríe."
	else:
		var cast: Dictionary = _piece.get("cast", {})
		out["ok"] = true
		out["sprueDiameterMm"] = float(cast.get("sprueDiameterMm", 0.0))
		out["sprueLengthMm"] = float(cast.get("sprueLengthMm", 0.0))
		if glass:
			out["realS"] = 86400.0
			out["text"] = "Un día después, ya a la temperatura ambiente, se rompe el molde con herramientas de madera o de plástico: sale la funda con su depósito, que se corta con la sierra de agua."
		else:
			out["text"] = "Molde roto: sale la funda con la forma de la garra y su bebedero de Ø %s mm, que hay que cortar con la sierra y limar." % Js.to_fixed(float(out.sprueDiameterMm), 1)
		_piece["divested"] = true
	_divest = out
	_event("desmoldar_" + ("ok" if out.ok else String(out.defect)), String(out.text), String(out.source))
	_serial += 1
	return out.duplicate(true)


## Una temperatura legible: «732 °C».
static func _fmt_c(t: float) -> String:
	return "%s °C" % Js.to_fixed(t, 0)


## Un tiempo legible (el mismo de la interfaz): «45 s» · «12 min» · «1 h 30 min» · «10.5 h» · «25 días (609 h)».
static func fmt_time(s: float) -> String:
	if s < 60.0:
		return "%s s" % Js.to_fixed(s, 0)
	if s < 3600.0:
		return "%s min" % Js.to_fixed(s / 60.0, 0)
	if s < 36000.0:
		var h := int(floor(s / 3600.0))
		var m := int(round((s - 3600.0 * float(h)) / 60.0))
		if m == 60:
			h += 1
			m = 0
		return "%d h" % h if m == 0 else "%d h %d min" % [h, m]
	if s < 172800.0:
		return "%s h" % Js.to_fixed(s / 3600.0, 1).trim_suffix(".0")
	return "%s días (%s h)" % [Js.to_fixed(s / 86400.0, 0), Js.to_fixed(s / 3600.0, 0)]


# ════════════════════════════════ Etapa 3 · enfriar ════════════════════════════════

## Saca la pieza del horno y la enfría en el medio (ForgeData.COOLING). { ok, medium, fromC, deltaC, limitC, defect, text }.
func cool(medium: String) -> Dictionary:
	var out := evaluate_cool(_piece, medium, _sheath)
	_cooled = out
	if not out.ok and bool(_piece.get("ok", false)):
		_piece["ok"] = false
		_piece["defect"] = out.defect
		_piece["text"] = out.text
		_piece["finish"] = "agrietado"
	if out.ok and bool(_piece.get("ok", false)):
		_piece["tempC"] = ROOM_C
	if out.ok:
		# sale de la máquina (y el molde de la cera perdida, con la pieza dentro)
		_loaded = {}
		_mold_in = false
		out["realS"] = cool_real_s(String(_piece.material), medium, float(out.fromC), _cool_half_mm(_piece, _sheath))
	for w: String in out.get("warnings", []):
		_event("enfriar_aviso", w, ForgeData.SRC_VERNEUIL)
	_event("enfriar_" + (String(out.defect) if out.defect != "" else "ok"), String(out.text), ForgeData.SRC_KINGERY + "; " + ForgeData.SRC_MANSON)
	_serial += 1
	return out.duplicate(true)


## Evaluación del enfriamiento (estática).
static func evaluate_cool(piece: Dictionary, medium: String, sh: Dictionary) -> Dictionary:
	var out := { "ok": false, "medium": medium, "fromC": ROOM_C, "deltaC": 0.0, "limitC": INF, "defect": "", "text": "", "warnings": [] }
	if piece.is_empty() or not bool(piece.get("ok", false)):
		out["defect"] = "sin_pieza"
		out["text"] = "No hay pieza buena que enfriar."
		return out
	if not ForgeData.COOLING.has(medium):
		out["defect"] = "medio"
		out["text"] = "Ese medio no existe."
		return out
	var mid := String(piece.material)
	var m := ForgeData.material(mid)
	var t0 := float(piece.get("tempC", ROOM_C))
	out["fromC"] = t0
	out["deltaC"] = t0 - ROOM_C
	var fam := String(m.get("family", ""))
	if fam == "vidrio" and medium != "horno" and t0 > float(m.anneal_c.value):
		out["defect"] = "sin_recocer"
		out["text"] = "El vidrio hay que recocerlo dentro del horno (a ~482-546 °C y luego despacio): enfriado así queda lleno de tensiones y se rompe solo."
		return out
	if m.get("inversion_c") != null and medium != "horno" and t0 >= float(m.inversion_c.value):
		out["defect"] = "inversion"
		out["text"] = "El cuarzo cruza los 573 °C deprisa: el cambio de fase (0,45 % de dilatación) lo agrieta."
		return out
	var a := 0.5 * float(sh.wallMm)
	match String(piece.get("form", "")):
		"bola":
			a = 0.5 * float(ForgeData.RECIPES.zafiro.growth.diameter_mm)
		"cristal", "bloque":
			a = 0.5 * float(sh.rawDiameterMm)
	var lim := shock_limit_c(mid, medium, a)
	out["limitC"] = lim
	if t0 - ROOM_C > lim:
		out["defect"] = "choque"
		out["text"] = "Choque térmico: un salto de %s °C contra los ~%s °C que aguanta enfriado así; la pieza se agrieta." % [Js.to_fixed(t0 - ROOM_C, 0), Js.to_fixed(lim, 0)]
		return out
	out["ok"] = true
	out["text"] = "Se enfría sin grietas." if is_finite(lim) or fam == "metal" else "Se enfría despacio, con el horno: sin choque."
	if String(piece.get("form", "")) == "bola" and medium != "horno":
		out.warnings.append("Una bola de Verneuil sale con tensión interna: en la fábrica se parte a lo largo para aliviarla antes de tallarla.")
	return out


## El medio espesor (mm) con que se enfría la pieza: el mismo del choque térmico de evaluate_cool.
static func _cool_half_mm(piece: Dictionary, sh: Dictionary) -> float:
	match String(piece.get("form", "")):
		"bola":
			return 0.5 * float(ForgeData.RECIPES.zafiro.growth.diameter_mm)
		"cristal", "bloque", "lingote":
			return 0.5 * float(sh.rawDiameterMm)
	return 0.5 * float(sh.wallMm)


## Lo que tarda de verdad en enfriarse hasta poder cogerla (ForgeData.COOL_HANDLE_C), en s (5m). Al aire, en aceite o en agua:
## capacidad concentrada, t = τ·ln((T0 − Ta)/(Tc − Ta)), τ = ρ·c·a/h, con el medio espesor a (V/A de una placa) y el
## coeficiente del medio (ForgeData.COOLING; Incropera). Estimación: no cuenta la radiación (al rojo enfría bastante más deprisa)
## ni el gradiente dentro de la pieza. Dentro del horno, el vidrio con su recocido (anneal_real_s); lo demás, sin cifra: −1.
static func cool_real_s(mat_id: String, medium: String, from_c: float, a_mm: float) -> float:
	var tc := float(ForgeData.COOL_HANDLE_C.value)
	if from_c <= tc:
		return 0.0
	if medium == "horno":
		return anneal_real_s(from_c) if String(ForgeData.material(mat_id).get("family", "")) == "vidrio" else -1.0
	var cool: Dictionary = ForgeData.COOLING.get(medium, {})
	var m := ForgeData.material(mat_id)
	var rho: Variant = ForgeData.density_of(mat_id)
	if cool.is_empty() or float(cool.h) <= 0.0 or m.get("cp") == null or rho == null:
		return -1.0
	var tau := float(rho) * float(m.cp.value) * a_mm / 1000.0 / float(cool.h)
	return tau * V8.js_log((from_c - ROOM_C) / (tc - ROOM_C))


## El recocido del vidrio colado hasta la temperatura ambiente, en s (5m; Bullseye, ForgeData.ANNEAL_GLASS): las bajadas a su
## ritmo y los mantenimientos. La primera bajada, la que haga el horno cerrado solo, no se cuenta (sin cifra).
static func anneal_real_s(from_c: float) -> float:
	var t := from_c
	var total := 0.0
	for seg: Dictionary in ForgeData.ANNEAL_GLASS.segments:
		var to := float(seg.to)
		if t > to:
			if float(seg.rate_c_s) > 0.0:
				total += (t - to) / float(seg.rate_c_s)
			t = to
			total += float(seg.hold_s)
	return total


# ════════════════════════════════ Etapa 4 · tallar ════════════════════════════════

## Talla la funda de la pieza con una muela: p { abrasive (ForgeData.ABRASIVES), grain_um, force_n, speed_ms, coolant
## (true: con agua) }. { ok, bites, eta, removedMm3, rateMm3s, timeS, depthUm, ductileDepthUm, regime («ductil» |
## «fragil»), edgeChipN, chipped, heatCrack, wheelBurn, defect, text }.
func carve(p: Dictionary) -> Dictionary:
	var out := evaluate_carve(_piece, p, _sheath)
	if bool(_piece.get("sprue", false)) and not bool(_piece.get("divested", false)) and bool(_piece.get("ok", false)):
		out = out.duplicate()
		out.merge({ "ok": false, "removedMm3": 0.0, "defect": "en_el_molde", "text": "La pieza sigue dentro del molde: primero hay que romperlo y sacarla.", "ruins": false }, true)
	_carved = out
	if out.ok:
		_piece["carved"] = true
		_piece["form_done"] = "funda"
		_piece["finish"] = "tallado"
		_surf = { "by": "talla", "material": String(_piece.material), "raUm": float(out.raUm), "chip": float(out.chip) }
		# de una vez, como todas las pasadas (5m): el tocho, la forma y el hueco hechos
		_cut = _cut_plan()
		_cut.merge({ "cuts": int(_cut.cutsNeed), "excessMm": 0.0, "hollowMm": float(_cut.hollowNeedMm), "passes": 1, "timeS": float(out.timeS),
			"lastTool": "muela", "raUm": float(out.raUm), "chip": float(out.chip), "done": true }, true)
	elif bool(out.get("ruins", false)):
		_piece["ok"] = false
		_piece["defect"] = out.defect
		_piece["text"] = out.text
		_piece["finish"] = "astillado" if out.defect == "astilla" else "agrietado"
	if bool(out.get("wheelBurn", false)):
		_event("muela_quemada", "La muela de diamante en seco se calienta y se quema: con agua.", ForgeData.SRC_KAPP + "; " + ForgeData.SRC_LAPIDARY)
	_event("tallar_" + (String(out.defect) if out.defect != "" else "ok"), String(out.text), ForgeData.SRC_ABRASIVES)
	_serial += 1
	return out.duplicate(true)


## Evaluación del tallado (estática). raUm: la rugosidad que deja la muela (Ra = h/4 con la hondura del surco de cada grano,
## ClawCare.groove_um; unidad 5j); chip: 1 si talla en régimen frágil (desconcha).
static func evaluate_carve(piece: Dictionary, p: Dictionary, sh: Dictionary) -> Dictionary:
	var out := {
		"ok": false, "bites": false, "eta": 0.0, "removedMm3": 0.0, "rateMm3s": 0.0, "timeS": INF, "depthUm": 0.0,
		"ductileDepthUm": null, "regime": "", "edgeChipN": INF, "chipped": false, "heatCrack": false, "wheelBurn": false,
		"wheelWear": "", "ruins": false, "defect": "", "text": "", "raUm": 0.0, "chip": 0.0,
	}
	if piece.is_empty() or not bool(piece.get("ok", false)):
		out["defect"] = "sin_pieza"
		out["text"] = "No hay pieza buena que tallar."
		return out
	var ab: Dictionary = ForgeData.ABRASIVES.get(String(p.get("abrasive", "diamante")), ForgeData.ABRASIVES.diamante)
	var mid := String(piece.material)
	var e: Dictionary = ForgeData.inlay_entry(mid)
	var hv := float(e.hv)
	var f := maxf(float(p.get("force_n", ForgeData.CARVE_DEFAULTS.force_n)), 0.0)
	var v := maxf(float(p.get("speed_ms", ForgeData.CARVE_DEFAULTS.speed_ms)), 0.0)
	var coolant := bool(p.get("coolant", true))
	var c_mm := float(ForgeData.CARVE_DEFAULTS.contact_mm)
	var tool := { "element": String(ab.element), "grain_um": float(p.get("grain_um", ab.grain_um)), "teeth_cm": float(ab.get("teeth_cm", 22.0)), "tool_hv": float(ab.hv) }
	var h_mpa := hv * Contact.HV_MPA
	var eta := bite_efficiency(float(ab.hv), hv)
	out["eta"] = eta
	out["bites"] = eta > 0.0
	var vol := float(sh.rawVolumeMm3) - float(sh.volumeMm3)
	if String(piece.form) in ["colada", "sinterizada", "capa"]:
		vol = (float(sh.innerAreaMm2) + 2.0 * PI * float(sh.outerRadiusMm) * float(sh.lengthMm)) * float(ForgeData.FINISH_SKIN_MM.value)
	out["removedMm3"] = vol
	if eta <= 0.0:
		out["defect"] = "no_muerde"
		out["text"] = "%s (%s HV) no muerde %s (%s HV): el abrasivo tiene que ser más duro que la pieza." % [String(ab.name), Js.to_fixed(float(ab.hv), 0), String(e.name).to_lower(), Js.to_fixed(hv, 0)]
		out["removedMm3"] = 0.0
		return out
	var ec := ClawCare.element_cut(tool, f, c_mm, c_mm, h_mpa)
	var rate := eta * float(ec.k) * f * v * 1000.0 / h_mpa
	out["rateMm3s"] = rate
	out["timeS"] = vol / rate if rate > 0.0 else INF
	out["depthUm"] = float(ec.depthUm)
	out["raUm"] = ClawCare.pass_ra_um(ClawCare.groove_um(tool, f, c_mm, c_mm, h_mpa))
	var st: Variant = ForgeData.strength_of(mid)
	var m := ForgeData.material(mid)
	var brittle: bool = st != null and String(st.kind) == "flexion"
	if brittle and st.kic != null:
		var dc := ductile_depth_um(float(e.E), hv, float(st.kic))
		out["ductileDepthUm"] = dc
		out["regime"] = "ductil" if float(ec.depthUm) <= dc else "fragil"
		out["chip"] = 1.0 if out.regime == "fragil" else 0.0
		var fc := edge_chip_n(float(st.kic), float(sh.wallMm))
		out["edgeChipN"] = fc
		if f >= fc:
			out["chipped"] = true
	elif not brittle:
		out["regime"] = "ductil"
	if not coolant:
		if brittle and m.get("k") != null and float(m.k.value) < DRY_CRACK_K:
			out["heatCrack"] = true
		if String(ab.id) == "diamante":
			out["wheelBurn"] = true
	# la muela: se quema (diamante en seco), se gasta químicamente (diamante o SiC contra el acero) o se gasta normal
	out["wheelWear"] = "quemada" if bool(out.wheelBurn) else ("quimico" if bool(ab.get("iron_reactive", false)) and bool(m.get("ferrous", false)) else "normal")
	if bool(out.chipped):
		out["ruins"] = true
		out["defect"] = "astilla"
		out["text"] = "Con %s N en un borde de %s mm, la pieza se desconcha (aguanta ~%s N): se astilla la funda." % [Js.to_fixed(f, 0), Js.to_fixed(float(sh.wallMm), 2), Js.to_fixed(float(out.edgeChipN), 0)]
		return out
	if bool(out.heatCrack):
		out["ruins"] = true
		out["defect"] = "grieta_calor"
		out["text"] = "Tallada en seco, el calor del roce agrieta una pieza frágil que conduce mal el calor: siempre con agua."
		return out
	out["ok"] = true
	out["text"] = "Funda tallada: %s mm³ en %s min." % [Js.to_fixed(vol, 0), Js.to_fixed(float(out.timeS) / 60.0, 1)]
	if out.wheelWear == "quimico":
		out["text"] = String(out.text) + " La muela se gasta deprisa: el diamante y el carburo de silicio reaccionan con el hierro en el contacto caliente; para el acero, corindón o CBN."
	return out


# ════════════════════════════════ Etapa 4b · el tallado por pasadas (5m) ════════════════════════════════

## Lo que hay que tallar de la pieza, por pasadas (5m): { kind («bloque»: la bola, el cristal, el bloque comprado o el lingote,
## de los que sale la funda entera; «colada»: la de la cera perdida, con su bebedero; «casi»: la sinterizada o la crecida sobre
## su molde, solo la piel), cutsNeed (los cortes de la sierra: los dos extremos de la bola, del cristal o del lingote; uno del
## bloque o del bebedero), cutAreaMm2, e0Mm (lo que sobra al empezar sobre la silueta de la funda, mm), vOutMm3 (lo que sobra
## por fuera), hollowNeedMm y vInMm3 (el hueco de dentro), outerAreaMm2 (la superficie de la funda, para lo que se come una
## pasada de más) }.
func _cut_plan() -> Dictionary:
	var form := String(_piece.get("form", ""))
	var sh := _sheath
	var skin_mm := float(ForgeData.FINISH_SKIN_MM.value)
	var plan := { "kind": "casi", "cutsNeed": 0, "cutAreaMm2": 0.0, "e0Mm": skin_mm, "vOutMm3": 0.0, "hollowNeedMm": 0.0, "vInMm3": 0.0,
		"outerAreaMm2": float(sh.innerAreaMm2) + 2.0 * PI * _wall_mm * float(sh.lengthMm) }
	var skin := (float(sh.innerAreaMm2) + 2.0 * PI * float(sh.outerRadiusMm) * float(sh.lengthMm)) * skin_mm
	match form:
		"bola", "cristal", "bloque", "lingote":
			var v_in := float(sh.get("innerVolumeMm3", 0.0))
			plan.merge({ "kind": "bloque", "cutsNeed": 1 if form == "bloque" else 2, "cutAreaMm2": PI * float(sh.outerRadiusMm) * float(sh.outerRadiusMm),
				"e0Mm": maxf(float(sh.outerRadiusMm) - _wall_mm, skin_mm), "vInMm3": v_in,
				"vOutMm3": maxf(float(sh.rawVolumeMm3) - float(sh.volumeMm3) - v_in, 0.0),
				"hollowNeedMm": float(sh.get("stumpCoverMm", sh.coverMm)) if v_in > 0.0 else 0.0 }, true)
		"colada":
			var d := float((_piece.get("cast", {}) as Dictionary).get("sprueDiameterMm", sprue_diameter_mm(sh)))
			var stub := float(ForgeData.SPRUE.stub_mm.value)
			plan.merge({ "kind": "colada", "cutsNeed": 1, "cutAreaMm2": 0.25 * PI * d * d, "e0Mm": stub, "vOutMm3": skin + 0.25 * PI * d * d * stub }, true)
		_:
			plan["vOutMm3"] = skin
	plan.merge({ "cuts": 0, "excessMm": float(plan.e0Mm), "hollowMm": 0.0, "passes": 0, "timeS": 0.0, "lastTool": "", "raUm": 0.0, "chip": 0.0,
		"wallLeftMm": _wall_mm, "done": false }, true)
	return plan


## Lo que le queda a cada herramienta de su meta en el tallado de ahora (5m): la sierra, cortes; la muela gruesa, más de una capa
## suya de sobra (lo demás es de la fina); la fresa, hueco; la fina, sobra sobre la silueta.
func _carve_goal_left(tid: String) -> bool:
	var plan := _cut if not _cut.is_empty() else _cut_plan()
	var tol := float(ForgeData.SHAPE_TOL.value)
	match tid:
		"sierra":
			return int(plan.cuts) < int(plan.cutsNeed)
		"muela_gruesa":
			return float(plan.excessMm) > float(ForgeData.CARVE_TOOLS.muela_gruesa.layer_mm) + 1e-9
		"fresa":
			return float(plan.hollowMm) < float(plan.hollowNeedMm) - 1e-9
		"muela_fina":
			return float(plan.excessMm) > tol
	return false


## Una pasada de tallado (5m; petición 42: la forma de la garra con las herramientas que tocan): p { tool (ForgeData.CARVE_TOOLS:
## «sierra», «muela_gruesa», «fresa» o «muela_fina»; la pulidora es polish()), abrasive (el material de la herramienta,
## ForgeData.ABRASIVES; por defecto, el diamante), force_n, speed_ms (por defecto, la de su máquina), coolant, light (una pasada
## suave: la cuarta parte) }.
## Cada herramienta quita lo suyo: la sierra, un corte (el canto del disco por la sección); la muela gruesa, una capa entera de
## lo que sobra sobre la silueta (no puede seguir la línea: si sobra menos, se pasa); la fina, una capa o lo que sobre (sigue la
## línea); la fresa, hueco por dentro. Una pasada de más con las muelas se come la funda (la pared queda más fina; si llega a
## cero, la agujerea). El tiempo, el volumen entre la tasa de arranque de Archard del motor (la de evaluate_carve) con el grano,
## la fuerza y la velocidad de esa herramienta; y los errores de §5: no muerde si es más blanda, en seco se agrieta lo frágil que
## conduce mal y se quema el diamante, y apretando de más se desconcha el borde (con la pared que queda).
## { ok, tool, name, abrasive, bites, eta, removedMm3, timeS (de verdad), rateMm3s, excessMm, hollowFrac, cuts, wallLeftMm, raUm,
##   chip, regime, edgeChipN, chipped, heatCrack, wheelBurn, wheelWear, ruins, done (la funda ya tiene su forma), verdict,
##   defect, text }.
func carve_pass(p: Dictionary) -> Dictionary:
	var tid := String(p.get("tool", "muela_fina"))
	var tool: Dictionary = ForgeData.CARVE_TOOLS.get(tid, {})
	var ab: Dictionary = ForgeData.ABRASIVES.get(String(p.get("abrasive", "diamante")), ForgeData.ABRASIVES.diamante)
	var light := bool(p.get("light", false))
	var coolant := bool(p.get("coolant", true))
	var f := maxf(float(p.get("force_n", ForgeData.CARVE_DEFAULTS.force_n)), 0.0)
	var out := { "ok": false, "tool": tid, "name": String(tool.get("name", "")), "abrasive": String(ab.id), "bites": false, "eta": 0.0,
		"removedMm3": 0.0, "timeS": 0.0, "rateMm3s": 0.0, "excessMm": 0.0, "hollowFrac": 0.0, "cuts": 0, "wallLeftMm": _wall_mm,
		"raUm": 0.0, "chip": 0.0, "regime": "", "edgeChipN": INF, "chipped": false, "heatCrack": false, "wheelBurn": false,
		"wheelWear": "", "ruins": false, "done": false, "verdict": "", "defect": "", "text": "", "light": light }
	if tool.is_empty() or String(tool.role) == "pulir":
		out["defect"] = "herramienta"
		out["text"] = "La pulidora no talla: pule."
	elif _piece.is_empty() or not bool(_piece.get("ok", false)):
		out["defect"] = "sin_pieza"
		out["text"] = "No hay pieza buena que tallar."
	elif _cooled.is_empty() or not bool(_cooled.get("ok", false)):
		out["defect"] = "caliente"
		out["text"] = "Primero hay que sacarla y dejar que se enfríe."
	elif bool(_piece.get("sprue", false)) and not bool(_piece.get("divested", false)):
		out["defect"] = "en_el_molde"
		out["text"] = "La pieza sigue dentro del molde: primero hay que romperlo y sacarla."
	if out.defect != "":
		_event("pasada_" + String(out.defect), String(out.text), ForgeData.SRC_ABRASIVES)
		_serial += 1
		return out.duplicate(true)
	if _cut.is_empty():
		_cut = _cut_plan()
	var plan := _cut
	var colada := String(plan.kind) == "colada"
	var tol := float(ForgeData.SHAPE_TOL.value)
	var frac := float(ForgeData.CARVE_LIGHT.value) if light else 1.0
	var cuts := int(plan.cuts)
	var excess := float(plan.excessMm)
	var hollow := float(plan.hollowMm)
	var dv := 0.0
	var edge := float(_sheath.outerRadiusMm)
	match String(tool.role):
		"cortar":
			if cuts >= int(plan.cutsNeed):
				out["defect"] = "nada_que_cortar"
				out["text"] = "El bebedero ya está cortado: ahora se lima lo que queda con la muela fina." if colada else "No queda nada que cortar con la sierra: sigue con las muelas."
			else:
				dv = float(plan.cutAreaMm2) * float(tool.kerf_mm)
				cuts += 1
		"desbastar", "formar":
			if cuts < int(plan.cutsNeed):
				out["defect"] = "sin_tocho"
				out["text"] = "Primero se corta el bebedero con la sierra." if colada else "Primero se saca el tocho con la sierra."
			else:
				var layer := float(tool.layer_mm) * frac
				# la gruesa siempre se lleva la capa entera; la fina sigue la línea mientras sobre algo
				var take := minf(layer, excess) if String(tool.role) == "formar" and excess > tol else layer
				if excess > tol:
					var on := minf(take, excess)
					dv = float(plan.vOutMm3) * on / float(plan.e0Mm) + float(plan.outerAreaMm2) * maxf(take - excess, 0.0)
				else:
					dv = float(plan.outerAreaMm2) * take
				excess -= take
				edge = _wall_mm + maxf(excess, 0.0)
		"vaciar":
			if cuts < int(plan.cutsNeed):
				out["defect"] = "sin_tocho"
				out["text"] = "Primero se saca el tocho con la sierra."
			elif hollow >= float(plan.hollowNeedMm) - 1e-9:
				out["defect"] = "nada_que_vaciar"
				out["text"] = "No hay nada que vaciar: la funda ya está hueca."
			else:
				var take2 := minf(float(tool.depth_mm) * frac, float(plan.hollowNeedMm) - hollow)
				dv = float(plan.vInMm3) * take2 / float(plan.hollowNeedMm)
				hollow += take2
				edge = _wall_mm + maxf(excess, 0.0)
	var mid := String(_piece.material)
	if out.defect == "":
		var e_entry: Dictionary = ForgeData.inlay_entry(mid)
		var hv := float(e_entry.hv)
		var h_mpa := hv * Contact.HV_MPA
		var eta := bite_efficiency(float(ab.hv), hv)
		out["eta"] = eta
		out["bites"] = eta > 0.0
		if eta <= 0.0:
			out["defect"] = "no_muerde"
			out["text"] = "%s (%s HV) no muerde %s (%s HV): la herramienta tiene que ser más dura que la pieza." % [String(ab.name), Js.to_fixed(float(ab.hv), 0), String(e_entry.name).to_lower(), Js.to_fixed(hv, 0)]
		else:
			var v := float(p.get("speed_ms", tool.speed_ms))
			var c_mm := float(ForgeData.CARVE_DEFAULTS.contact_mm)
			var el := { "element": String(ab.element), "grain_um": float(tool.get("grain_um", ab.grain_um)), "teeth_cm": float(ab.get("teeth_cm", 22.0)), "tool_hv": float(ab.hv) }
			var ec := ClawCare.element_cut(el, f, c_mm, c_mm, h_mpa)
			var rate := eta * float(ec.k) * f * v * 1000.0 / h_mpa
			out["rateMm3s"] = rate
			out["removedMm3"] = dv
			out["timeS"] = dv / rate if rate > 0.0 else INF
			out["raUm"] = ClawCare.pass_ra_um(ClawCare.groove_um(el, f, c_mm, c_mm, h_mpa))
			var st: Variant = ForgeData.strength_of(mid)
			var m := ForgeData.material(mid)
			var brittle: bool = st != null and String(st.kind) == "flexion"
			if brittle and st.kic != null:
				var dc := ductile_depth_um(float(e_entry.E), hv, float(st.kic))
				out["regime"] = "ductil" if float(ec.depthUm) <= dc else "fragil"
				out["chip"] = 1.0 if out.regime == "fragil" else 0.0
				var fc := edge_chip_n(float(st.kic), edge)
				out["edgeChipN"] = fc
				out["chipped"] = f >= fc
			elif not brittle:
				out["regime"] = "ductil"
			if not coolant:
				out["heatCrack"] = brittle and m.get("k") != null and float(m.k.value) < DRY_CRACK_K
				out["wheelBurn"] = String(ab.id) == "diamante"
			out["wheelWear"] = "quemada" if bool(out.wheelBurn) else ("quimico" if bool(ab.get("iron_reactive", false)) and bool(m.get("ferrous", false)) else "normal")
			if bool(out.chipped):
				out["ruins"] = true
				out["defect"] = "astilla"
				out["text"] = "Con %s N en un borde de %s mm, la pieza se desconcha (aguanta ~%s N): se astilla." % [Js.to_fixed(f, 0), Js.to_fixed(edge, 2), Js.to_fixed(float(out.edgeChipN), 0)]
			elif bool(out.heatCrack):
				out["ruins"] = true
				out["defect"] = "grieta_calor"
				out["text"] = "Tallada en seco, el calor del roce agrieta una pieza frágil que conduce mal el calor: siempre con agua."
			elif _wall_mm + minf(excess, 0.0) <= 0.0:
				out["ruins"] = true
				out["defect"] = "agujero"
				out["text"] = "Te has pasado de la silueta: la muela se ha comido la pared entera y la funda se agujerea."
	if out.defect == "" or bool(out.ruins):
		plan["passes"] = int(plan.passes) + 1
		plan["timeS"] = float(plan.timeS) + float(out.timeS)
		plan["lastTool"] = tid
	if out.defect == "":
		plan["cuts"] = cuts
		plan["excessMm"] = excess
		plan["hollowMm"] = hollow
		plan["raUm"] = float(out.raUm)
		plan["chip"] = float(out.chip)
		plan["wallLeftMm"] = _wall_mm + minf(excess, 0.0)
		out["ok"] = true
		var done := cuts >= int(plan.cutsNeed) and hollow >= float(plan.hollowNeedMm) - 1e-9 and excess <= tol
		plan["done"] = done
		if done and float(plan.get("seamMm", 0.0)) > 0.0:
			plan["seamMm"] = 0.0
		if String(tool.role) in ["desbastar", "formar", "vaciar"] and (done or bool(_piece.get("carved", false))):
			# la funda tiene su forma (o se repasa ya hecha: lo pulido vuelve a quedar tallado)
			_piece["carved"] = true
			_piece["form_done"] = "funda"
			_piece["finish"] = "tallado"
			_surf = { "by": "talla", "material": mid, "raUm": float(out.raUm), "chip": float(out.chip) }
			_polish = {}
		_carved = { "ok": bool(_piece.get("carved", false)), "bites": true, "removedMm3": float(out.removedMm3), "timeS": float(plan.timeS), "raUm": float(out.raUm),
			"chip": float(out.chip), "regime": String(out.regime), "defect": "", "text": "", "ruins": false, "byPasses": true }
	elif bool(out.ruins):
		_piece["ok"] = false
		_piece["defect"] = out.defect
		_piece["text"] = out.text
		_piece["finish"] = "agrietado" if out.defect == "grieta_calor" else "astillado"
		_carved = { "ok": false, "bites": true, "ruins": true, "defect": String(out.defect), "text": String(out.text), "chipped": bool(out.chipped), "heatCrack": bool(out.heatCrack), "byPasses": true }
	elif String(out.defect) == "no_muerde":
		_carved = { "ok": false, "bites": false, "defect": "no_muerde", "text": String(out.text), "ruins": false, "byPasses": true }
	var cs := carve_state()
	out["excessMm"] = float(plan.excessMm)
	out["hollowFrac"] = float(cs.hollowFrac)
	out["cuts"] = int(plan.cuts)
	out["wallLeftMm"] = float(plan.wallLeftMm)
	out["done"] = bool(plan.done)
	out["verdict"] = String(cs.verdict)
	if out.ok:
		out["text"] = "%s: %s mm³ en %s de verdad. %s" % [String(tool.short), Js.to_fixed(float(out.removedMm3), 1), fmt_time(float(out.timeS)), String(cs.text)]
		if out.wheelWear == "quimico":
			out["text"] = String(out.text) + " La herramienta se gasta deprisa: el diamante y el carburo de silicio reaccionan con el hierro; para el acero, corindón o CBN."
	if bool(out.wheelBurn):
		_event("muela_quemada", "La herramienta de diamante en seco se calienta y se quema: con agua.", ForgeData.SRC_KAPP + "; " + ForgeData.SRC_LAPIDARY)
	_event("pasada_" + (String(out.defect) if out.defect != "" else tid), String(out.text), String(tool.source) if out.defect == "" else ForgeData.SRC_ABRASIVES)
	_serial += 1
	return out.duplicate(true)


## Pasadas con una herramienta hasta su meta (5m; lo que hace «Hazlo como dice el paso»): la sierra, hasta sacar el tocho o
## cortar el bebedero; la muela gruesa, mientras sobra más de una capa suya (lo demás es de la fina, que sigue la línea); la
## fresa, hasta vaciar la funda; la fina, hasta la silueta. p, los de carve_pass. Devuelve la última pasada, con passes y
## timeS (los de esta llamada); si no había nada que hacer, { ok, passes: 0, text }.
func carve_to(p: Dictionary) -> Dictionary:
	var tid := String(p.get("tool", "muela_fina"))
	var last := {}
	var n := 0
	var t := 0.0
	for i in 200:
		if not _carve_goal_left(tid):
			break
		last = carve_pass(p)
		if not bool(last.ok):
			break
		n += 1
		t += float(last.timeS)
	if last.is_empty():
		last = { "ok": not _piece.is_empty() and bool(_piece.get("ok", false)), "tool": tid, "text": "Nada que hacer con esta herramienta.", "defect": "" }
	last["passes"] = n
	last["timeS"] = t
	return last


## El tallado de ahora (5m), para el indicador de la forma y la escena: { started, kind, cuts, cutsNeed, excessMm, e0Mm,
## hollowFrac, passes, timeS, wallLeftMm, done, lastTool, verdict («sin_empezar», «tocho», «desbaste», «casi», «vaciar»,
## «correcta», «fina», «rota»), tone, text, profile { s, target, now (los radios por fuera, mm, a lo largo de la garra desde su
## base), apex, wall, raw } }. La silueta de la pieza va de la del tocho a la de la funda en proporción a lo que sobra (dibujo).
func carve_state() -> Dictionary:
	var plan := _cut if not _cut.is_empty() else (_cut_plan() if not _piece.is_empty() else {})
	var out := { "started": not _cut.is_empty(), "kind": String(plan.get("kind", "")), "cuts": int(plan.get("cuts", 0)), "cutsNeed": int(plan.get("cutsNeed", 0)),
		"excessMm": float(plan.get("excessMm", 0.0)), "e0Mm": float(plan.get("e0Mm", 0.0)), "hollowFrac": 1.0, "passes": int(plan.get("passes", 0)),
		"timeS": float(plan.get("timeS", 0.0)), "wallLeftMm": float(plan.get("wallLeftMm", _wall_mm)), "done": bool(plan.get("done", false)) or bool(_piece.get("carved", false)),
		"lastTool": String(plan.get("lastTool", "")), "verdict": "sin_empezar", "tone": "", "text": "", "profile": {} }
	if plan.is_empty():
		return out
	if float(plan.hollowNeedMm) > 0.0:
		out["hollowFrac"] = clampf(float(plan.hollowMm) / float(plan.hollowNeedMm), 0.0, 1.0)
	var tol := float(ForgeData.SHAPE_TOL.value)
	var e := float(plan.excessMm)
	var coarse := float(ForgeData.CARVE_TOOLS.muela_gruesa.layer_mm)
	var v := "sin_empezar"
	var tone := ""
	var text := ""
	var colada := String(plan.kind) == "colada"
	if not bool(_piece.get("ok", false)):
		v = "rota"
		tone = "mal"
		text = String(_piece.get("text", "La pieza se ha estropeado."))
	elif int(plan.cuts) < int(plan.cutsNeed):
		v = "tocho"
		text = "Falta cortar el bebedero con la sierra." if colada else "Falta sacar el tocho con la sierra (%d de %d cortes)." % [int(plan.cuts), int(plan.cutsNeed)]
	elif e > coarse + 1e-9:
		v = "desbaste"
		text = "Sobran %s mm sobre la silueta de la garra: desbastar con la muela gruesa." % Js.to_fixed(e, 2)
	elif e > tol:
		v = "casi"
		tone = "aviso"
		text = "Sobran %s mm: con la muela fina, que sigue la línea (la gruesa se pasaría)." % Js.to_fixed(e, 2)
		if float(plan.get("seamMm", 0.0)) > 0.0:
			text = "El cordón de la soldadura sobresale %s mm: límalo con la muela fina hasta la silueta." % Js.to_fixed(e, 2)
	elif e < -tol:
		# pasarse de la silueta se dice ya, esté o no vaciada
		v = "fina"
		tone = "aviso" if float(plan.wallLeftMm) > 0.5 * _wall_mm else "mal"
		text = "Te has pasado %s mm de la silueta: la pared queda de %s mm (era de %s)." % [Js.to_fixed(-e, 2), Js.to_fixed(float(plan.wallLeftMm), 2), Js.to_fixed(_wall_mm, 2)]
	elif float(out.hollowFrac) < 1.0:
		v = "vaciar"
		tone = "aviso"
		text = "Por fuera ya tiene la forma; falta vaciarla por dentro con la fresa (%s %%)." % Js.to_fixed(float(out.hollowFrac) * 100.0, 0)
	else:
		v = "correcta"
		tone = "bien"
		text = "La forma de la garra: correcta, contra su silueta."
	out["verdict"] = v
	out["tone"] = tone
	out["text"] = text
	out["profile"] = _carve_profile(plan)
	return out


## La silueta de la pieza que se talla contra la de la funda (5m; dibujo, en el marco de la garra: s desde su base): la funda, el
## radio de la garra sana de su dedo más la pared, hasta la punta y un tapón de la pared; la pieza, entre el tocho (el cilindro
## que la contiene) y la funda en proporción a lo que sobra, y más fina si se ha pasado. { s, target, now, apex, wall, raw }.
func _carve_profile(plan: Dictionary) -> Dictionary:
	var care: Variant = _care
	var apex: float = care.apex_mm()
	var cov := minf(float(_sheath.coverMm), apex)
	var n := 24
	var ss := PackedFloat64Array()
	var tg := PackedFloat64Array()
	var nw := PackedFloat64Array()
	var raw := float(_sheath.outerRadiusMm)
	for i in n:
		var s := apex - cov + cov * float(i) / float(n - 1)
		raw = maxf(raw, float(care.radius_at(s)) + _wall_mm)
	var e := float(plan.excessMm)
	var e0 := maxf(float(plan.e0Mm), 1e-9)
	var block := String(plan.kind) == "bloque"
	for i in n + 4:
		var s := 0.0
		var t := 0.0
		if i < n:
			s = apex - cov + cov * float(i) / float(n - 1)
			t = float(care.radius_at(s)) + _wall_mm
		else:
			# el tapón de la punta: un cuarto de círculo de la pared
			var a := float(i - n + 1) / 4.0 * PI * 0.5
			s = apex + _wall_mm * V8.js_sin(a)
			t = maxf((float(care.radius_at(apex)) + _wall_mm) * V8.js_cos(a), 0.0)
		var now := t
		if e > 0.0:
			now = t + ((raw if block else t + e0) - t) * (e / e0)
		else:
			now = maxf(t + e, 0.0)
		ss.append(s)
		tg.append(t)
		nw.append(now)
	return { "s": ss, "target": tg, "now": nw, "apex": apex, "wall": _wall_mm, "raw": raw }


# ════════════════════════════════ Etapa 5 · proteger y recubrir ════════════════════════════════

## Pone una barrera térmica sobre la carne viva: p { barrier (ForgeData.BARRIER_IDS), thickness_mm }.
func protect(p: Dictionary) -> Dictionary:
	var bid := String(p.get("barrier", ""))
	var b: Dictionary = ForgeData.BARRIERS.get(bid, {})
	var th := maxf(float(p.get("thickness_mm", 0.0)), 0.0)
	_barrier = { "ok": not b.is_empty() and th > 0.0, "barrier": bid, "name": String(b.get("name", "")), "thicknessMm": th, "maxC": float(b.get("max_c", 0.0)) }
	_event("proteger", "Barrera de %s de %s mm sobre la carne viva." % [String(b.get("name", "nada")).to_lower(), Js.to_fixed(th, 1)], String(b.get("source", "")))
	_serial += 1
	return _barrier.duplicate(true)


## Las dos vías del calor de un recubrimiento sobre la garra viva, que cubre cover_mm desde la punta (por defecto, lo que
## cubriría la funda):
## { liveWallMm: la pared de queratina más fina sobre la carne viva bajo la capa (−1 si la capa no llega a la parte viva),
##   tipDistanceMm: la distancia más corta de la queratina muerta recubierta a la carne viva, en línea recta (como el flanco
##   de ClawCare; −1 si no hay punta muerta bajo la capa), quickCoverMm, coverMm }. La barrera solo va sobre la parte viva:
## para agarrar, la capa toca directamente la queratina de la punta.
func live_paths(cover_mm: float = -1.0) -> Dictionary:
	var care: Variant = _care
	var apex: float = care.apex_mm()
	var sq: float = apex - float(care.quick_cover_mm())
	var cov := clampf(cover_mm if cover_mm > 0.0 else _cover_mm, 0.1, apex)
	var wall := INF
	var tip := INF
	for i in 201:
		var s := apex - cov + cov * float(i) / 200.0
		var r := float(care.radius_at(s))
		if s < sq:
			wall = minf(wall, maxf(r - float(care.core_at(s)), 0.0))
		else:
			tip = minf(tip, sqrt((s - sq) * (s - sq) + r * r))
	return {
		"liveWallMm": maxf(wall, SLAB_DX_MM) if is_finite(wall) else -1.0,
		"tipDistanceMm": maxf(tip, SLAB_DX_MM) if is_finite(tip) else -1.0,
		"quickCoverMm": float(care.quick_cover_mm()), "coverMm": cov,
	}


## Distancia (mm) de la superficie recubierta más cercana a la carne viva (la menor de las dos vías de live_paths).
func live_wall_mm() -> float:
	var lp := live_paths()
	var best := INF
	for key: String in ["liveWallMm", "tipDistanceMm"]:
		if float(lp[key]) > 0.0:
			best = minf(best, float(lp[key]))
	return best if is_finite(best) else SLAB_DX_MM


## FICCIÓN: el calor de una capa a t_c durante time_s sobre cover_mm de la garra viva (desde la punta), por las dos vías de
## live_paths: la parte viva,
## bajo la barrera que haya puesto protect(), y la punta muerta, que la capa toca directamente (barrier_heating sin barrera).
## { keratinPeakC (la queratina más caliente: en la punta, la de la capa), quickPeakC, charred, tipCharred, pain,
##   injuryDose, injured, barrierFails, viaLive y viaTip (los barrier_heating de cada vía, o null), paths }.
func live_coat_heating(t_c: float, time_s: float, cover_mm: float = -1.0) -> Dictionary:
	var lp := live_paths(cover_mm)
	var via_live: Variant = null
	var via_tip: Variant = null
	if float(lp.liveWallMm) > 0.0:
		via_live = barrier_heating(t_c, time_s, String(_barrier.get("barrier", "")), float(_barrier.get("thicknessMm", 0.0)), float(lp.liveWallMm))
	if float(lp.tipDistanceMm) > 0.0:
		via_tip = barrier_heating(t_c, time_s, "", 0.0, float(lp.tipDistanceMm))
	var bed: float = CareData.THERMAL.bed_c.value
	var out := {
		"keratinPeakC": bed, "quickPeakC": bed, "charred": false, "tipCharred": false, "pain": false, "injuryDose": 0.0,
		"injured": false, "barrierFails": false, "charC": float(CareData.THERMAL.char_c.value), "viaLive": via_live,
		"viaTip": via_tip, "paths": lp,
	}
	for v: Variant in [via_live, via_tip]:
		if v == null:
			continue
		out["keratinPeakC"] = maxf(float(out.keratinPeakC), float(v.keratinPeakC))
		out["quickPeakC"] = maxf(float(out.quickPeakC), float(v.quickPeakC))
		out["injuryDose"] = maxf(float(out.injuryDose), float(v.injuryDose))
		out["charred"] = bool(out.charred) or bool(v.charred)
		out["pain"] = bool(out.pain) or bool(v.pain)
		out["injured"] = bool(out.injured) or bool(v.injured)
	out["tipCharred"] = via_tip != null and bool(via_tip.charred)
	out["barrierFails"] = via_live != null and bool(via_live.barrierFails)
	return out


## Recubre: p { method (ForgeData.COATING_IDS), target («funda» | «garra_viva»), time_s, cycles (ALD), material (lo que se
## vierte, en «fundido»), cover_mm (en la garra viva: cuánto se recubre desde la punta; por defecto, lo que cubriría la
## funda) }. En la funda: real si el sustrato lo admite y aguanta la temperatura. En la garra viva: FICCIÓN,
## con el calor por las dos vías (live_coat_heating). { ok, fiction, method, target, thicknessUm, hv, material,
## benchDepthLimitUm (la huella que la capa aún manda, el 10 % de su espesor), thermal, finish, porosity, defect, text,
## fictionWhy, tC }.
func coat(p: Dictionary) -> Dictionary:
	var mid_c := String(p.get("method", ""))
	var c: Dictionary = ForgeData.COATINGS.get(mid_c, {})
	var target := String(p.get("target", "funda"))
	var out := {
		"ok": false, "fiction": false, "method": mid_c, "name": String(c.get("name", "")), "target": target, "thicknessUm": 0.0,
		"hv": null, "material": "", "benchDepthLimitUm": 0.0, "thermal": null, "finish": "", "porosity": float(c.get("porosity", 0.0)),
		"defect": "", "text": "", "fictionWhy": [], "tC": 0.0,
	}
	if c.is_empty():
		out["defect"] = "metodo"
		out["text"] = "Ese recubrimiento no existe."
		_coat = out
		return out.duplicate(true)
	var cmat := String(c.product)
	if mid_c == "fundido":
		cmat = String(p.get("material", _piece.get("material", "zafiro")))
	out["material"] = cmat
	var thick := float(c.thick_um)
	if mid_c == "ald_alumina":
		thick = maxf(float(p.get("cycles", 300.0)), 0.0) * float(c.per_cycle_um)
	out["thicknessUm"] = thick
	out["hv"] = c.hv
	if mid_c == "fundido":
		var ce: Variant = ForgeData.inlay_entry(cmat)
		out["hv"] = float(ce.hv) if ce != null else null
	out["benchDepthLimitUm"] = 0.1 * thick
	var t_c := float(c.t_c)
	if mid_c == "fundido":
		var mm := ForgeData.material(cmat)
		t_c = float(mm.melt_c.value) if mm.get("melt_c") != null else (float(mm.soften_c.value) if mm.get("soften_c") != null else 2000.0)
	out["tC"] = t_c
	var note := ""
	if String(c.product) == "alumina" and String(_piece.get("material", "")) in ["zafiro", "rubi"]:
		note = " Es alúmina, no zafiro: una capa depositada sale amorfa o policristalina; el zafiro es un monocristal que solo crece desde el fundido."
	if target == "garra_viva":
		var why: Array = out.fictionWhy
		why.append("Nadie recubre la garra de un animal vivo: se hace una funda aparte y se pega en frío, como una corona dental.")
		if bool(c.vacuum):
			why.append("%s: se hace en una cámara de vacío, y un animal vivo no puede entrar." % String(c.name))
		if bool(c.get("bath", false)):
			why.append("%s: la garra iría pintada con pintura conductora y sumergida con corriente en un baño de ácido crómico (cromo hexavalente, cancerígeno) durante horas." % String(c.name))
		var ce2: Variant = ForgeData.inlay_entry(cmat)
		if mid_c == "fundido":
			why.append("Verter %s fundido (%s °C) sobre una garra: la queratina se quema a ~%s °C." % [String(ce2.name).to_lower() if ce2 != null else cmat, Js.to_fixed(t_c, 0), Js.to_fixed(float(CareData.THERMAL.char_c.value), 0)])
		var t_def := 600.0
		if mid_c == "fundido":
			t_def = 10.0
		elif c.has("rate_um_h"):
			t_def = thick / float(c.rate_um_h) * 3600.0
		var time := maxf(float(p.get("time_s", t_def)), 0.0)
		var th := live_coat_heating(t_c, time, float(p.get("cover_mm", -1.0)))
		out["coverMm"] = float(th.paths.coverMm)
		out["thermal"] = th
		out["fiction"] = true
		for w: String in why:
			if not _fiction.has(w):
				_fiction.append(w)
		if bool(th.tipCharred):
			out["defect"] = "garra_quemada"
			out["text"] = "La capa a %s °C toca la queratina de la punta: pasa de ~%s °C, se quema y la capa se funde con la queratina carbonizada. La barrera solo protege la parte viva." % [Js.to_fixed(t_c, 0), Js.to_fixed(float(th.charC), 0)]
		elif bool(th.charred):
			out["defect"] = "garra_quemada"
			out["text"] = "La queratina sobre la carne viva llega a %s °C: se quema y la capa se funde con la garra carbonizada." % Js.to_fixed(float(th.keratinPeakC), 0)
		elif bool(th.injured):
			out["defect"] = "carne_lesionada"
			out["text"] = "La queratina aguanta, pero la carne viva llega a %s °C el tiempo suficiente para lesionarse." % Js.to_fixed(float(th.quickPeakC), 0)
		elif bool(th.barrierFails):
			out["defect"] = "barrera_falla"
			out["text"] = "La barrera no aguanta %s °C: se descompone y deja de proteger." % Js.to_fixed(t_c, 0)
		else:
			out["ok"] = true
			out["finish"] = "poroso" if float(out.porosity) > 0.0 else "bruto"
			out["text"] = "FICCIÓN: la queratina se queda en %s °C y la carne viva en %s °C. En la realidad no se hace." % [Js.to_fixed(float(th.keratinPeakC), 0), Js.to_fixed(float(th.quickPeakC), 1)]
	else:
		if _piece.is_empty() or not bool(_piece.get("carved", false)) or not bool(_piece.get("ok", false)):
			out["defect"] = "sin_funda"
			out["text"] = "Primero hay que tener la funda tallada (o colada) aparte."
		elif mid_c == "fundido":
			out["defect"] = "metodo"
			out["text"] = "Verter material fundido sobre la funda no es un recubrimiento: se hace la funda entera de ese material."
		else:
			var sub := String(_piece.material)
			var subs: Array = c.substrates
			var hs := heat_state(sub, t_c, "vacio" if bool(c.vacuum) else "aire")
			if not subs.is_empty() and not subs.has(sub):
				out["defect"] = "sustrato"
				out["text"] = "El recubrimiento («%s») no agarra sobre %s." % [String(c.name).to_lower(), String(ForgeData.inlay_entry(sub).name).to_lower()]
				if mid_c == "cvd_diamante" and sub == "acero":
					out["text"] = "El diamante CVD no crece sobre acero: el hierro disuelve el carbono (sustratos buenos: Si, Mo, W, Ti, diamante)."
			elif bool(hs.melted) or bool(hs.softened) or bool(hs.oxidized) or bool(hs.graphitized):
				out["defect"] = "sustrato_calor"
				out["text"] = "La funda no aguanta los %s °C del recubrimiento: se deforma o se quema." % Js.to_fixed(t_c, 0)
			else:
				out["ok"] = true
				if bool(c.get("conductive_layer", false)) and String(ForgeData.material(sub).get("family", "")) != "metal":
					note += " Antes, una capa de pintura conductora: la funda no conduce."
				match mid_c:
					"plasma_alumina":
						out["finish"] = "poroso"
					"esmalte":
						out["finish"] = "pulido"
					"cvd_diamante":
						out["finish"] = "bruto"
					_:
						out["finish"] = String(_piece.get("finish", "tallado"))
				out["text"] = "Funda recubierta: %s µm de %s." % [Js.to_fixed(thick, 3 if thick < 1.0 else 0), String(c.name).to_lower()]
	if out.ok and out.hv != null:
		out["text"] = String(out.text) + " En el banco la capa manda solo mientras la punta no se hunda más de %s µm (el 10 %% de su espesor)." % Js.to_fixed(float(out.benchDepthLimitUm), 3 if float(out.benchDepthLimitUm) < 1.0 else 1)
	if out.ok:
		out["text"] = String(out.text) + note
	_coat = out
	# una capa de al menos 1 µm sobre la funda es lo que se ve (su acabado) hasta que se pula (unidad 5j)
	if out.ok and not bool(out.fiction) and _surface_is_coat():
		_surf = { "by": "capa", "material": String(_coat.material), "raUm": 0.0, "chip": 0.0 }
	_event("recubrir_" + (String(out.defect) if out.defect != "" else "ok"), String(out.text), String(c.source))
	_serial += 1
	return out.duplicate(true)


# ════════════════════════════════ Etapa 6 · unir en frío ════════════════════════════════

## Pega la funda en frío: p { adhesive (ForgeData.ADHESIVE_IDS), gap_mm }. { ok, adhesive, gapMm, areaMm2, cures, tauMPa,
## capacityN, limitedBy, defect, text }.
func bond(p: Dictionary) -> Dictionary:
	var aid := String(p.get("adhesive", "epoxi"))
	if aid == String(ForgeData.BRAZE.id):
		var bz: Dictionary = ForgeData.BRAZE
		var outb := {
			"ok": false, "adhesive": aid, "name": String(bz.name), "gapMm": 0.0, "areaMm2": float(_sheath.innerAreaMm2), "cures": false,
			"tauMPa": 0.0, "capacityN": 0.0, "limitedBy": "calor", "defect": "garra_quemada",
			"text": "La soldadura fuerte funde a %s-%s °C y la queratina se quema a ~%s °C: no se pega una funda a una garra soldando. Sirve para unir piezas de metal de la funda (una punta de metal duro sobre acero) antes de pegarla en frío." % [Js.to_fixed(float(bz.t_min), 0), Js.to_fixed(float(bz.t_max), 0), Js.to_fixed(float(CareData.THERMAL.char_c.value), 0)],
		}
		_bond = outb
		_event("unir_soldadura", String(outb.text), String(bz.source))
		_serial += 1
		return outb.duplicate(true)
	var a: Dictionary = ForgeData.ADHESIVES.get(aid, {})
	var gap := float(p.get("gap_mm", a.get("gap_ideal", 0.1)))
	var out := { "ok": false, "adhesive": aid, "name": String(a.get("name", "")), "gapMm": gap, "areaMm2": float(_sheath.innerAreaMm2), "defect": "", "text": "" }
	if _piece.is_empty() or not bool(_piece.get("carved", false)) or not bool(_piece.get("ok", false)):
		out["defect"] = "sin_funda"
		out["text"] = "No hay funda buena que pegar."
	elif float(_sheath.innerAreaMm2) <= 0.0:
		# la garra rota (unidad 5j): una funda que no llega a lo que queda de ella no tiene dónde pegarse
		out["defect"] = "sin_superficie"
		out["text"] = "La funda no llega a lo que queda de la garra (faltan %s mm desde la punta y cubre %s mm): no hay dónde pegarla. Para una garra rota, la prótesis entera, que cubre el muñón." % [Js.to_fixed(float(_sheath.goneMm), 1), Js.to_fixed(float(_sheath.coverMm), 1)]
	else:
		var cap := bond_capacity(aid, gap, float(_sheath.innerAreaMm2), _humidity)
		out.merge(cap, true)
		if not bool(cap.cures):
			out["defect"] = "no_cura"
			out["text"] = "Con %s mm de holgura el %s no cura (llena como mucho %s mm): la funda no queda pegada." % [Js.to_fixed(gap, 2), String(a.name).to_lower(), Js.to_fixed(float(a.gap_max), 2)]
		else:
			out["ok"] = true
			out["text"] = "Pegada en frío: aguanta ~%s N de cortante (manda %s)." % [Js.to_fixed(float(cap.capacityN), 0), "la queratina" if cap.limitedBy == "queratina" else "el adhesivo"]
	_bond = out
	_event("unir_" + (String(out.defect) if out.defect != "" else "ok"), String(out.text), String(a.get("source", "")))
	_serial += 1
	return out.duplicate(true)


## Prueba el ajuste de la funda en la garra, sin pegarla (petición 43: pegarla es de la cetrería, sobre el animal). p { gap_mm
## (la holgura con que se hizo la funda; por defecto, la ideal del epoxi) }. La holgura que queda es la de diseño más lo que cambia
## una colada que no se compensó (el radio interior medio por la escala de la colada menos uno; 0 en una pieza tallada). Entra si
## no es negativa, y cada adhesivo la llena hasta su holgura máxima (Henkel). { ok, enters, gapMm, designGapMm, castDeltaMm,
## innerRadiusMm, adhesives [{ id, name, fills, ideal }], defect, text, source }.
func fit(p: Dictionary = {}) -> Dictionary:
	var design := float(p.get("gap_mm", float(ForgeData.ADHESIVES.epoxi.gap_ideal)))
	var out := { "ok": false, "enters": false, "gapMm": 0.0, "designGapMm": design, "castDeltaMm": 0.0, "innerRadiusMm": 0.0, "adhesives": [],
		"defect": "", "text": "", "source": ForgeData.SRC_LOCTITE_GUIDE + "; " + ForgeData.SRC_LOCTITE_401 }
	if _piece.is_empty() or not bool(_piece.get("carved", false)) or not bool(_piece.get("ok", false)):
		out["defect"] = "sin_funda"
		out["text"] = "Primero hay que tener la funda terminada: tallada, o colada y limada."
	elif float(_sheath.innerAreaMm2) <= 0.0:
		out["defect"] = "sin_superficie"
		out["text"] = "La funda no llega a lo que queda de la garra: no hay dónde ajustarla. Para una garra rota, la prótesis entera, que cubre el muñón."
	else:
		var L := maxf(float(_sheath.get("stumpCoverMm", _sheath.coverMm)), 1e-6)
		var r_in := float(_sheath.innerAreaMm2) / (2.0 * PI * L)
		var dlt := r_in * (float((_piece.get("cast", {}) as Dictionary).get("scale", 1.0)) - 1.0)
		var gap := design + dlt
		var fills_any := false
		var parts: Array = []
		for aid: String in ForgeData.ADHESIVE_IDS:
			var a: Dictionary = ForgeData.ADHESIVES[aid]
			var fills := gap >= 0.0 and gap <= float(a.gap_max) + 1e-9
			var ideal := fills and gap >= float(a.gap_ideal_min) - 1e-9 and gap <= float(a.gap_ideal) + 1e-9
			fills_any = fills_any or fills
			out.adhesives.append({ "id": aid, "name": String(a.name), "fills": fills, "ideal": ideal })
			var short := String(a.name).split(" (")[0].to_lower()
			parts.append("el %s %s" % [short, "la llena bien" if ideal else ("la llena" if fills else "no (llena hasta %s mm)" % Js.to_fixed(float(a.gap_max), 2))])
		out.merge({ "gapMm": gap, "castDeltaMm": dlt, "innerRadiusMm": r_in, "enters": gap >= 0.0, "ok": gap >= 0.0 and fills_any }, true)
		var cast_note := ""
		if absf(dlt) >= 0.0005:
			cast_note = " (la colada salió %s mm %s por dentro)" % [Js.to_fixed(absf(dlt), 3), "más ancha" if dlt > 0.0 else "más estrecha"]
		if not bool(out.enters):
			out["defect"] = "no_entra"
			out["text"] = "No entra en la garra: la colada salió %s mm más estrecha por dentro (la contracción sin compensar). Hay que colarla otra vez con la cera a la medida de la contracción, o abrir el hueco con la fresa." % Js.to_fixed(-dlt, 3)
		else:
			out["text"] = "Entra en la garra con %s mm de holgura%s: %s. Se pega en la cetrería, sobre el animal." % [Js.to_fixed(gap, 3), cast_note, ", ".join(parts)]
	_fit = out
	_event("ajuste_" + ("ok" if out.ok else String(out.defect) if String(out.defect) != "" else "holgura"), String(out.text), String(out.source))
	_serial += 1
	return out.duplicate(true)


# ════════════════════════════════ Etapa 6b · soldar piezas de metal (5r) ════════════════════════════════

## La segunda pieza de la soldadura: la punta de la funda (los últimos TIP_FRAC del tramo que cubre), de otro material o del
## mismo; o una funda rota que se repara por la misma costura. La costura va alrededor de la funda en esa estación (dibujo y
## elección del ensayo: la unión de la punta de una herramienta, como una plaquita).
const WELD_TIP_FRAC := 0.3
const WELD_PARTS := { "punta": "La punta de la funda (otra pieza)", "reparar": "Reparar la funda rota (la misma pieza)" }

## La costura de la soldadura en la funda: { sMm (la estación, desde la base de la garra), radiusMm (por fuera), lengthMm
## (la circunferencia), wallMm, tipFrac }.
func weld_seam_geometry() -> Dictionary:
	var care: Variant = _care
	var apex: float = care.apex_mm()
	var cov := minf(float(_sheath.coverMm), apex)
	var s := apex - cov * WELD_TIP_FRAC
	var r := float(care.radius_at(s)) + _wall_mm
	return { "sMm": s, "radiusMm": r, "lengthMm": 2.0 * PI * r, "wallMm": _wall_mm, "tipFrac": WELD_TIP_FRAC }


## ¿Hay una pieza de metal (o de metal duro) buena y fría con la que soldar? { ok, defect, text }.
func _weld_piece_ready() -> Dictionary:
	if _piece.is_empty() or not bool(_piece.get("ok", false)):
		return { "ok": false, "defect": "sin_pieza", "text": "No hay pieza buena que soldar." }
	if _cooled.is_empty() or not bool(_cooled.get("ok", false)):
		return { "ok": false, "defect": "caliente", "text": "Primero hay que sacarla y dejar que se enfríe." }
	if bool(_piece.get("sprue", false)) and not bool(_piece.get("divested", false)):
		return { "ok": false, "defect": "en_el_molde", "text": "La pieza sigue dentro del molde: primero hay que romperlo y sacarla." }
	var fam := ClawWeld.family_of(String(_piece.material))
	if fam != "metal" and fam != "metal_duro":
		return { "ok": false, "defect": "no_metal", "text": "Solo se sueldan piezas de metal: %s se engasta o se pega." % String(ForgeData.inlay_entry(String(_piece.material)).name).to_lower() }
	return { "ok": true, "defect": "", "text": "" }


## Prepara la soldadura (5r): p { method («laser», «tig» o «braze»), part («punta» o «reparar»), material (la segunda pieza; por
## defecto, el de la pieza), energy_j, pulse_ms, spot_mm (láser), current_a (micro-TIG), gas (ClawWeld.GAS_IDS), overlap (fracción),
## temp_c y gap_mm (soldadura fuerte), align_mm (lo que las piezas están desalineadas: la holgura de la junta, como mucho el 10 %
## de la pared) }. Evalúa el punto (o la plata) y la costura, y deja los tramos sin soldar: cada weld_pulse pone un punto.
## { ok, defect, text, canJoin, spot, seam, braze, pulsesNeed, alignMm, aligned, alignMaxMm, source }.
func weld_setup(p: Dictionary) -> Dictionary:
	var method := String(p.get("method", "laser"))
	var part := String(p.get("part", "punta"))
	var a := String(_piece.get("material", ""))
	var b := String(p.get("material", a))
	if part == "reparar":
		b = a
	var gas := String(p.get("gas", "argon"))
	if not ClawWeld.GAS_IDS.has(gas):
		gas = "argon"
	var geo := weld_seam_geometry()
	var align := maxf(float(p.get("align_mm", 0.0)), 0.0)
	var align_max := 0.1 * _wall_mm
	var out := { "ok": false, "defect": "", "text": "", "method": method, "part": part, "a": a, "b": b, "gas": gas, "canJoin": {}, "spot": {}, "seam": {},
		"braze": {}, "pulsesNeed": 0, "alignMm": align, "aligned": align <= align_max + 1e-9, "alignMaxMm": align_max, "geometry": geo,
		"params": p.duplicate(true), "source": String((ClawWeld.METHODS.get(method, {}) as Dictionary).get("source", "")) }
	var ready := _weld_piece_ready()
	if not ClawWeld.METHODS.has(method):
		out["defect"] = "metodo"
		out["text"] = "Ese método no existe."
	elif not bool(ready.ok):
		out["defect"] = String(ready.defect)
		out["text"] = String(ready.text)
	else:
		var cj := ClawWeld.can_join(a, b, method)
		out["canJoin"] = cj
		if method == "braze":
			var bz := ClawWeld.braze(a, b, float(p.get("temp_c", ClawWeld.METHODS.braze.controls.temp_c.value)), float(p.get("gap_mm", ClawWeld.METHODS.braze.controls.gap_mm.value)))
			out["braze"] = bz
			# la plata recorre la costura por tramos del ancho de un punto del soplete (elección del juego: ~2 mm por tramo)
			out["seam"] = { "pulsesNeed": maxi(int(ceil(float(geo.lengthMm) / 2.0)), 1), "pitchMm": 2.0, "overlap": 0.0, "effDepthMm": _wall_mm if bool(bz.flows) else 0.0,
				"fusion": 1.0 if bool(bz.flows) else 0.0, "through": bool(bz.flows), "perforated": false, "beadMm": 0.1, "wallMm": _wall_mm, "lengthMm": float(geo.lengthMm),
				"text": "", "source": String(bz.source) }
			out["ok"] = bool(cj.ok)
			out["defect"] = "" if bool(cj.ok) else String(cj.code)
			out["text"] = String(bz.text) if bool(cj.ok) else String(cj.text)
		else:
			var spot := ClawWeld.laser_spot(a, float(p.get("energy_j", 12.0)), float(p.get("pulse_ms", 4.0)), float(p.get("spot_mm", 0.6)), gas) if method == "laser" else ClawWeld.tig_spot(a, float(p.get("current_a", 150.0)), float(p.get("pulse_ms", 8.0)), gas)
			out["spot"] = spot
			out["seam"] = ClawWeld.seam(spot, _wall_mm, float(geo.lengthMm), float(p.get("overlap", 0.65)))
			out["ok"] = bool(cj.ok) and bool(spot.get("ok", false))
			out["defect"] = "" if bool(cj.ok) else String(cj.code)
			if bool(cj.ok) and not bool(spot.get("ok", false)):
				out["defect"] = String(spot.defect)
			out["text"] = String(cj.text) + ((" " + String(spot.get("text", ""))) if bool(cj.ok) else "")
		out["pulsesNeed"] = int((out.seam as Dictionary).get("pulsesNeed", 0))
		if bool(out.ok) and not bool(out.aligned):
			out["text"] = String(out.text) + " Las piezas están desalineadas %s mm (la junta admite como mucho %s mm, el 10 %% de la pared): alinéalas antes de soldar." % [Js.to_fixed(align, 2), Js.to_fixed(align_max, 2)]
	var segs := PackedInt32Array()
	segs.resize(int(out.pulsesNeed))
	_weld = out.duplicate(true)
	_weld["segments"] = segs
	_weld["pulses"] = 0
	_weld["remelts"] = 0
	_weld["covered"] = 0
	_weld["done"] = false
	_weld["joint"] = {}
	_event("soldar_" + ("lista" if out.ok else String(out.defect)), String(out.text), String(out.source))
	_serial += 1
	return out.duplicate(true)


## Alinea las piezas (5r): deja la desalineación en align_mm (la del banco de soldar).
func weld_align(align_mm: float) -> Dictionary:
	if _weld.is_empty():
		return { "ok": false, "defect": "sin_soldadura", "text": "Primero prepara la soldadura." }
	var a := maxf(align_mm, 0.0)
	_weld["alignMm"] = a
	_weld["aligned"] = a <= float(_weld.alignMaxMm) + 1e-9
	_serial += 1
	return { "ok": bool(_weld.aligned), "alignMm": a, "aligned": bool(_weld.aligned), "alignMaxMm": float(_weld.alignMaxMm),
		"text": ("Alineadas: la junta queda con %s mm." % Js.to_fixed(a, 2)) if bool(_weld.aligned) else ("Desalineadas %s mm: la junta admite como mucho %s mm." % [Js.to_fixed(a, 2), Js.to_fixed(float(_weld.alignMaxMm), 2)]) }


## Un punto (o un tramo del soplete) en la posición u (0-1) de la costura (5r). { ok, defect, segment, remelt, pulses, pulsesNeed,
## covered, progress, done, text }. Un tramo ya soldado se refunde (remelt); el motor no para por eso, pero lo cuenta.
func weld_pulse(p: Dictionary) -> Dictionary:
	var out := { "ok": false, "defect": "", "segment": -1, "remelt": false, "pulses": int(_weld.get("pulses", 0)), "pulsesNeed": int(_weld.get("pulsesNeed", 0)),
		"covered": int(_weld.get("covered", 0)), "progress": 0.0, "done": bool(_weld.get("done", false)), "text": "" }
	if _weld.is_empty() or not bool(_weld.get("ok", false)):
		out["defect"] = "sin_soldadura" if _weld.is_empty() else String(_weld.defect)
		out["text"] = "Primero prepara la soldadura (el método, la segunda pieza y sus mandos)." if _weld.is_empty() else String(_weld.text)
		return out
	if not bool(_weld.aligned):
		out["defect"] = "desalineada"
		out["text"] = "Las piezas están desalineadas %s mm: el baño no cierra el hueco. Alinéalas antes." % Js.to_fixed(float(_weld.alignMm), 2)
		return out
	if bool(_weld.done):
		out["defect"] = "hecha"
		out["text"] = "La costura ya está entera."
		return out
	var n := int(_weld.pulsesNeed)
	var u := clampf(float(p.get("u", 0.0)), 0.0, 0.999999)
	var i := clampi(int(floor(u * float(n))), 0, n - 1)
	var segs: PackedInt32Array = _weld.segments
	var remelt := segs[i] > 0
	segs[i] += 1
	_weld["segments"] = segs
	_weld["pulses"] = int(_weld.pulses) + 1
	if remelt:
		_weld["remelts"] = int(_weld.remelts) + 1
	var cov := 0
	for k in n:
		if segs[k] > 0:
			cov += 1
	_weld["covered"] = cov
	out.merge({ "ok": true, "segment": i, "remelt": remelt, "pulses": int(_weld.pulses), "covered": cov, "progress": float(cov) / float(n), "method": String(_weld.method) }, true)
	var what := "Tramo" if String(_weld.method) == "braze" else "Punto"
	out["text"] = "%s %d de %d%s." % [what, cov, n, " (refundido: ya tenía el suyo)" if remelt else ""]
	if cov >= n:
		var j := weld_finish()
		out["done"] = true
		out["text"] = String(j.text)
	_serial += 1
	return out


## Cierra la costura (5r): con todos los tramos soldados, evalúa la unión (ClawWeld.joint) y la aplica a la pieza: si sale, queda
## un cordón que sobresale beadMm sobre la silueta (se lima con la muela fina) y la unión va con la pieza; si falla (perforada,
## contaminada, intermetálicos, la plata que no moja), la pieza queda estropeada con su defecto. { ok, defect, text, joint }.
func weld_finish() -> Dictionary:
	var out := { "ok": false, "defect": "", "text": "", "joint": {} }
	if _weld.is_empty() or not bool(_weld.get("ok", false)):
		out["defect"] = "sin_soldadura"
		out["text"] = "No hay soldadura preparada."
		return out
	if bool(_weld.done):
		out["defect"] = "hecha"
		out["text"] = "La costura ya está entera."
		out["joint"] = (_weld.joint as Dictionary).duplicate(true)
		return out
	var n := int(_weld.pulsesNeed)
	var cov := int(_weld.covered)
	if cov < n:
		out["defect"] = "incompleta"
		out["text"] = "Faltan %d %s de %d: la costura no está entera." % [n - cov, "tramos" if String(_weld.method) == "braze" else "puntos", n]
		return out
	var j := ClawWeld.joint(String(_weld.method), String(_weld.a), String(_weld.b), _weld.spot, _weld.seam, String(_weld.gas), _weld.braze)
	# el soplete que insiste agota el fundente (elección del juego: más de REMELT_MAX pasadas de más por cada cuarto de la costura)
	if String(_weld.method) == "braze" and int(_weld.remelts) > ClawWeld.REMELT_MAX * maxi(n / 4, 1) and bool(j.ok):
		j["ok"] = false
		j["defect"] = "fundente_agotado"
		j["text"] = "Tanto soplete sobre la misma costura agota el fundente: la unión se oxida y la plata deja huecos."
	_weld["done"] = true
	_weld["joint"] = j.duplicate(true)
	out["joint"] = j.duplicate(true)
	out["defect"] = String(j.defect)
	out["text"] = String(j.text)
	out["ok"] = bool(j.ok)
	var mname := String((ClawWeld.METHODS[String(_weld.method)] as Dictionary).short)
	var rec := { "method": String(_weld.method), "methodName": mname, "part": String(_weld.part), "tipMaterial": String(_weld.b), "ok": bool(j.ok), "defect": String(j.defect),
		"jointMPa": float(j.jointMPa), "baseMPa": float(j.baseMPa), "efficiency": float(j.efficiency), "limitedBy": String(j.limitedBy),
		"color": (j.get("color", {}) as Dictionary).duplicate(true), "contaminated": bool(j.contaminated), "porosity": bool(j.porosity), "cracks": bool(j.cracks),
		"pulses": int(_weld.pulses), "remelts": int(_weld.remelts), "hazMm": float((_weld.spot as Dictionary).get("hazMm", 0.0)), "depthMm": float((_weld.seam as Dictionary).get("effDepthMm", 0.0)),
		"wallMm": _wall_mm, "text": String(j.text), "source": String(j.source), "quality": "secondary" if String(_weld.method) != "braze" and String(_weld.a) == "oro" else "estimate" }
	_piece["weld"] = rec
	if bool(j.ok):
		# el cordón sobresale: hay que limarlo con la muela fina antes de pulir
		if _cut.is_empty():
			_cut = _cut_plan()
		var bead := float((_weld.seam as Dictionary).get("beadMm", 0.1))
		_cut["excessMm"] = maxf(float(_cut.excessMm), 0.0) + bead
		_cut["seamMm"] = bead
		_cut["done"] = false
		_polish = {}
		_fit = {}
		if bool(_piece.get("carved", false)):
			_piece["finish"] = "tallado"
			_surf = { "by": "talla", "material": String(_piece.material), "raUm": float(_cut.get("raUm", 0.0)), "chip": float(_cut.get("chip", 0.0)) }
	else:
		_piece["ok"] = false
		_piece["defect"] = "soldadura_" + String(j.defect)
		_piece["text"] = String(j.text)
		_piece["finish"] = "oxidado" if bool(j.contaminated) else ("agrietado" if bool(j.cracks) else "defectuoso")
	_event("soldadura_" + (String(j.defect) if j.defect != "" else "ok"), String(j.text), String(j.source))
	_serial += 1
	return out


## La soldadura para la escena y la interfaz (5r): { on, ready, done, method, part, a, b, gas, pulses, pulsesNeed, covered, progress,
## remelts, segments [int], alignMm, aligned, alignMaxMm, spot, seam, braze, joint, canJoin, geometry, text }. {} sin preparar.
func weld_state() -> Dictionary:
	if _weld.is_empty():
		return {}
	var segs: Array = []
	for v in (_weld.segments as PackedInt32Array):
		segs.append(int(v))
	var n := int(_weld.pulsesNeed)
	return {
		"on": true, "ready": bool(_weld.ok), "done": bool(_weld.done), "method": String(_weld.method), "part": String(_weld.part), "a": String(_weld.a), "b": String(_weld.b),
		"gas": String(_weld.gas), "pulses": int(_weld.pulses), "pulsesNeed": n, "covered": int(_weld.covered), "progress": float(_weld.covered) / float(maxi(n, 1)),
		"remelts": int(_weld.remelts), "segments": segs, "alignMm": float(_weld.alignMm), "aligned": bool(_weld.aligned), "alignMaxMm": float(_weld.alignMaxMm),
		"spot": (_weld.spot as Dictionary).duplicate(true), "seam": (_weld.seam as Dictionary).duplicate(true), "braze": (_weld.braze as Dictionary).duplicate(true),
		"joint": (_weld.joint as Dictionary).duplicate(true), "canJoin": (_weld.canJoin as Dictionary).duplicate(true), "geometry": (_weld.geometry as Dictionary).duplicate(true),
		"defect": String(_weld.defect), "text": String(_weld.text), "source": String(_weld.source),
	}


# ════════════════════════════════ Etapa 7 · pulir ════════════════════════════════

## Pule la superficie (la capa si la hay; si no, la funda): p { abrasive, grain_um, sharpen }. Solo muerde lo más duro.
## Pulir no cambia la forma: la punta sigue con su radio natural. Con sharpen, además se afila: la punta queda del radio de
## la arista o del grano (CareData.TOOTH_GEOMETRY o GRAIN_GEOMETRY) y el afilado sale de ClawSharpness. { ok, bites, eta,
## surface, surfaceHv, tipRadiusUm, sharpness, chipLoadN (la carga de lado que mella la punta), raUm (la rugosidad que deja
## el grano, con la fuerza y el contacto de ForgeData.PIECE_SURFACE; unidad 5j), depthUm, ductileDepthUm, regime, chip,
## onCoat, defect, text }.
func polish(p: Dictionary) -> Dictionary:
	var ab: Dictionary = ForgeData.ABRASIVES.get(String(p.get("abrasive", "diamante")), ForgeData.ABRASIVES.diamante)
	var surf := _surface_material()
	var out := { "ok": false, "bites": false, "eta": 0.0, "surface": surf, "surfaceHv": null, "grainUm": float(p.get("grain_um", ab.grain_um)), "tipRadiusUm": null, "sharpness": 0.0, "chipLoadN": null,
		"raUm": 0.0, "depthUm": 0.0, "ductileDepthUm": null, "regime": "", "chip": 0.0, "onCoat": false, "defect": "", "text": "" }
	if surf == "":
		out["defect"] = "sin_funda"
		out["text"] = "No hay nada que pulir."
	else:
		var on_coat := _surface_is_coat()
		var e: Variant = ForgeData.inlay_entry(surf)
		var hv := 0.0
		if on_coat and _coat.get("hv") != null:
			hv = float(_coat.hv)
		elif e != null:
			hv = float(e.hv)
		out["surfaceHv"] = hv
		var eta := bite_efficiency(float(ab.hv), hv) if hv > 0.0 else 1.0
		out["eta"] = eta
		out["bites"] = eta > 0.0
		if eta <= 0.0:
			out["defect"] = "no_muerde"
			out["text"] = "%s (%s HV) resbala sobre %s HV: no muerde. Para pulir hace falta un abrasivo más duro (el diamante para el zafiro)." % [String(ab.name), Js.to_fixed(float(ab.hv), 0), Js.to_fixed(hv, 0)]
		else:
			var r0 := ClawSharpness.radius_um_of_area(float(_claw.area))
			var edge := float((CareData.TOOTH_GEOMETRY if String(ab.element) == "diente" else CareData.GRAIN_GEOMETRY).tip_um)
			var r := minf(r0, maxf(edge, ClawSharpness.SHARPEST_UM)) if bool(p.get("sharpen", false)) else r0
			out["tipRadiusUm"] = r
			out["sharpness"] = ClawSharpness.sharpness_for(r0, r)
			var st: Variant = ForgeData.strength_of(surf)
			if st != null:
				out["chipLoadN"] = ClawSharpness.chip_load_n(ClawSharpness.tip_of(r, float(_claw.alpha)), float(st.value))
			out["ok"] = true
			out["text"] = "Pulida con %s de %s µm: la punta queda de ~%s µm de radio." % [String(ab.name).to_lower(), Js.to_fixed(float(out.grainUm), 0), Js.to_fixed(r, 0)]
			if out.chipLoadN != null:
				out["text"] = String(out.text) + " Se mellaría con ~%s de lado." % Format.fmt_small_force(float(out.chipLoadN))
			out.merge(polish_surface(ab, float(out.grainUm), surf, hv), true)
			out["onCoat"] = on_coat
			if on_coat:
				_coat["finish"] = "pulido"
			else:
				_piece["finish"] = "pulido"
			_surf = { "by": "pulido", "material": surf, "raUm": float(out.raUm), "chip": float(out.chip) }
	_polish = out
	_event("pulir_" + (String(out.defect) if out.defect != "" else "ok"), String(out.text), ForgeData.SRC_ABRASIVES + "; " + ForgeData.SRC_FILE_TEST)
	_serial += 1
	return out.duplicate(true)


## La superficie que deja el grano de pulir ab (de grain_um) en el material mat_id de dureza hv (unidad 5j), con la fuerza y el
## contacto de la pulidora (ForgeData.PIECE_SURFACE): { raUm (Ra = h/4, ClawCare.pass_ra_um, con la hondura del surco de cada
## grano), depthUm, ductileDepthUm (d_c de Bifano, si es frágil y tiene datos; null si no), regime («ductil» | «fragil» |
## «»), chip (1 si pule en régimen frágil: desconcha) }.
static func polish_surface(ab: Dictionary, grain_um: float, mat_id: String, hv: float) -> Dictionary:
	var ps: Dictionary = ForgeData.PIECE_SURFACE
	var f := float(ps.polish_force_n)
	var c := float(ps.polish_contact_mm)
	var tool := { "element": String(ab.element), "grain_um": grain_um, "teeth_cm": float(ab.get("teeth_cm", 22.0)), "tool_hv": float(ab.hv) }
	var h_mpa := hv * Contact.HV_MPA
	var out := { "raUm": 0.0, "depthUm": 0.0, "ductileDepthUm": null, "regime": "", "chip": 0.0 }
	if h_mpa <= 0.0:
		return out
	out["raUm"] = ClawCare.pass_ra_um(ClawCare.groove_um(tool, f, c, c, h_mpa))
	var depth := float(ClawCare.element_cut(tool, f, c, c, h_mpa).depthUm)
	out["depthUm"] = depth
	var st: Variant = ForgeData.strength_of(mat_id)
	var e: Variant = ForgeData.inlay_entry(mat_id)
	if st != null and String(st.kind) == "flexion" and st.kic != null and e != null:
		var dc := ductile_depth_um(float(e.E), hv, float(st.kic))
		out["ductileDepthUm"] = dc
		out["regime"] = "ductil" if depth <= dc else "fragil"
		out["chip"] = 1.0 if out.regime == "fragil" else 0.0
	elif st != null:
		out["regime"] = "ductil"
	return out


## La superficie de la pieza (unidad 5j; lo pidió la 5f): la que deja lo último que la ha tocado, la muela al tallarla o el
## grano al pulirla (el de la capa, si es la capa lo que se pule), igual a lo largo de la pieza, con la forma que lee la
## biblioteca de materiales (ClawMaterial.surface_image), como la de la cetrería. Sin tallar, rota o con una capa sin pulir:
## ok = false (la superficie es la de su acabado). { ok, by («talla» | «pulido»), material, raUm, chip, scratchDeg,
## stations [{ ra_um, burn, chip, scratch_deg }], lengthMm, quality, source }.
func surface() -> Dictionary:
	var ps: Dictionary = ForgeData.PIECE_SURFACE
	var out := { "ok": false, "by": "", "material": "", "raUm": 0.0, "chip": 0.0, "scratchDeg": float(ps.scratch_deg), "stations": [],
		"lengthMm": float(_sheath.lengthMm), "quality": String(ps.quality), "source": String(ps.source) }
	if not bool(_piece.get("ok", false)) or not bool(_piece.get("carved", false)) or not (String(_surf.get("by", "")) in ["talla", "pulido"]):
		return out
	out["ok"] = true
	out["by"] = String(_surf.by)
	out["material"] = String(_surf.material)
	out["raUm"] = float(_surf.raUm)
	out["chip"] = float(_surf.chip)
	var st: Array = []
	for i in int(ps.stations):
		st.append({ "ra_um": float(out.raUm), "burn": 0.0, "chip": float(out.chip), "scratch_deg": float(out.scratchDeg) })
	out["stations"] = st
	return out


## ¿La superficie que se pule es la capa? Sí si hay una capa buena de al menos 1 µm (más fina, se gasta al primer pase).
func _surface_is_coat() -> bool:
	return not _coat.is_empty() and bool(_coat.get("ok", false)) and float(_coat.get("thicknessUm", 0.0)) >= 1.0


## El material de la superficie: el de la capa (_surface_is_coat), si no el de la funda; «» si no hay nada que pulir.
func _surface_material() -> String:
	if _surface_is_coat():
		return String(_coat.material)
	if bool(_piece.get("carved", false)) and bool(_piece.get("ok", false)):
		return String(_piece.material)
	return ""


# ════════════════════════════════ Etapa 8 · comprobar ════════════════════════════════

## Carga la garra: p { load_n (por defecto, la fuerza de la ficha del animal) }. La funda pegada se despega si la carga, como
## cortante sobre la unión, pasa de lo que aguanta (suposición: toda la fuerza tira de la funda). { ok, loadN, capacityN,
## detached, verdict, text }.
func check_load(p: Dictionary) -> Dictionary:
	var load := maxf(float(p.get("load_n", float(_claw.force))), 0.0)
	var out := { "ok": false, "loadN": load, "capacityN": null, "detached": false, "text": "" }
	if bool(_coat.get("fiction", false)) and bool(_coat.get("ok", false)):
		out["ok"] = true
		out["text"] = "FICCIÓN: la capa forma parte de la garra; no hay unión que despegar."
	elif _bond.is_empty() or not bool(_bond.get("ok", false)):
		out["text"] = "La funda no está pegada."
		out["detached"] = true
	else:
		var cap := float(_bond.capacityN)
		out["capacityN"] = cap
		out["detached"] = load > cap
		out["ok"] = not bool(out.detached)
		out["text"] = ("Se despega: %s N contra los ~%s N que aguanta la unión." if out.detached else "Aguanta: %s N contra los ~%s N de la unión.") % [Js.to_fixed(load, 0), Js.to_fixed(cap, 0)]
	_check = out
	_event("comprobar_" + ("ok" if out.ok else "despega"), String(out.text), String(_bond.get("source", ForgeData.KERATIN_SHEAR.source)))
	_serial += 1
	return out.duplicate(true)


# ════════════════════════════════ Lecturas ════════════════════════════════

## La garra resultante para el banco, el coche en marcha y la cetrería:
## { ok, inlay (el material: un id de Data.INLAYS o uno nuevo de la 2.0, ForgeData.NEW_MATERIALS; «none» si la garra sigue
##   siendo de queratina, con una capa fina encima), inBench (el banco ya lo tiene), benchTwin (el del banco con la misma
##   mecánica: el rubí es zafiro; «» si no hay), name, hv, E, densityKgM3, strengthMPa, kic, sheathMassKg, clawMassKg
##   (queratina + funda), addedKg, finish (ForgeData.FINISH_IDS: el acabado de la superficie que se ve), coating, bond,
##   tipRadiusUm, sharpness, quality («ficcion» si se recubrió la garra viva), fiction [razones], source }.
func result_claw() -> Dictionary:
	var out := {
		"ok": false, "inlay": "none", "inBench": true, "benchTwin": "none", "name": "", "hv": null, "E": null, "densityKgM3": null,
		"strengthMPa": null, "kic": null, "sheathMassKg": 0.0, "clawMassKg": 0.0, "addedKg": 0.0, "finish": "", "coating": null,
		"bond": null, "tipRadiusUm": null, "sharpness": 0.0, "quality": "", "fiction": _fiction.duplicate(), "source": "", "weld": null,
	}
	var ker_rho: float = ClawMass.DENSITY.none.value
	var v_ker := float(_sheath.keratinVolumeMm3)
	out["clawMassKg"] = ker_rho * v_ker * 1.0e-9
	var mid := ""
	if bool(_coat.get("fiction", false)) and bool(_coat.get("ok", false)):
		# la garra viva recubierta (ficción): la capa fina no cambia el material de la garra para el banco (sigue siendo de
		# queratina); la capa va aparte, con la huella que aún manda
		out["coating"] = _coat_view()
		out["quality"] = "ficcion"
		out["finish"] = String(_coat.get("finish", "bruto"))
		out["ok"] = true
	elif _finished():
		# la funda terminada (petición 43: tallada, protegida o recubierta, y pulida); pegarla es de la cetrería
		mid = String(_piece.material)
		out["quality"] = String(_piece.get("quality", "secondary"))
		out["ok"] = true
		out["finish"] = String(_piece.get("finish", "tallado"))
		if bool(_coat.get("ok", false)):
			out["coating"] = _coat_view()
			out["finish"] = String(_coat.get("finish", out.finish))
		if bool(_bond.get("ok", false)):
			out["bond"] = { "adhesive": String(_bond.adhesive), "capacityN": float(_bond.capacityN), "limitedBy": String(_bond.limitedBy) }
	elif not _piece.is_empty():
		out["finish"] = String(_piece.get("finish", ""))
	# la unión soldada de la pieza (5r), con lo que aguanta frente al metal base; null sin soldar
	out["weld"] = (_piece.weld as Dictionary).duplicate(true) if _piece.has("weld") else null
	if mid != "":
		var e: Dictionary = ForgeData.inlay_entry(mid)
		var rho: float = ForgeData.density_of(mid)
		var st: Variant = ForgeData.strength_of(mid)
		out["inlay"] = mid
		out["inBench"] = ForgeData.in_bench(mid)
		out["benchTwin"] = ForgeData.bench_twin(mid)
		out["name"] = String(e.name)
		out["hv"] = float(e.hv)
		out["E"] = float(e.E)
		out["densityKgM3"] = rho
		out["strengthMPa"] = float(st.value) if st != null else null
		out["kic"] = st.kic if st != null else null
		var m_sh := rho * float(_sheath.volumeMm3) * 1.0e-9
		out["sheathMassKg"] = m_sh
		out["addedKg"] = m_sh
		out["clawMassKg"] = float(out.clawMassKg) + m_sh
		out["source"] = String(_piece.get("source", ""))
	if not _polish.is_empty() and bool(_polish.get("ok", false)):
		out["tipRadiusUm"] = _polish.tipRadiusUm
		out["sharpness"] = float(_polish.sharpness)
	return out


## ¿Está la funda terminada? Tallada (o colada y limada), buena y pulida (petición 43: el laboratorio acaba aquí, sin pegarla;
## si se probó con la carga y se despegó, no).
func _finished() -> bool:
	return bool(_piece.get("carved", false)) and bool(_piece.get("ok", false)) and bool(_polish.get("ok", false)) and not bool(_check.get("detached", false))


func _coat_view() -> Dictionary:
	return {
		"method": String(_coat.method), "material": String(_coat.material), "hv": _coat.hv, "thicknessUm": float(_coat.thicknessUm),
		"benchDepthLimitUm": float(_coat.benchDepthLimitUm), "fiction": bool(_coat.fiction), "finish": String(_coat.get("finish", "")),
		"porosity": float(_coat.get("porosity", 0.0)),
	}


## Lo que la cetrería necesita para seguir limando o afilando la garra reforjada con ClawCare: { animal, claw, inlay,
## careSupported, reason }. El material va con su propio id (unidad 5g): ClawCare conoce los de Catalog.INLAYS, los de la
## 1.x y los nuevos de la 2.0 (el rubí y la alúmina; ClawCare.supports_inlay). Si la cetrería no lo conociera, la queratina
## («none») y careSupported = false, con el porqué.
## La garra rota que se reforja (petición 35): from_care son los ajustes de la ClawCare de la garra rota con stump_mm (lo
## que queda de ella, mm desde la base: su punta de ahora). En cuanto la pieza del horno (o la comprada) sale bien y se
## enfría, sin tallar, vuelve como un bloque en bruto pegado al muñón: { …los ajustes de from_care, inlay «none»,
## block: { material, stump_mm, wall_mm (la pared de la funda: lo que sobra alrededor y delante del largo natural),
## fiction, quality, note, source } }, que se lima en la cetrería con herramientas más duras que el material. FICCIÓN: en
## la realidad la pieza se talla aparte y se pega terminada; en el animal solo se pega y se lima una prótesis de acrílico.
## Esa es la vía real (unidad 5j): con el acrílico dental (ForgeData.PROSTHESIS) el bloque no es ficción.
func care_setup(from_care: Dictionary = {}) -> Dictionary:
	var out := { "animal": String(_animal.id), "claw": String(_claw.id), "inlay": "none", "careSupported": true, "reason": "" }
	if from_care.has("stump_mm"):
		for key: String in ["digit", "paw", "overgrowth_days", "humidity", "sedation", "seed", "quick"]:
			if from_care.has(key):
				out[key] = from_care[key]
		var mid := String(_piece.get("material", ""))
		if not bool(_piece.get("ok", false)) or _cooled.is_empty() or not bool(_cooled.get("ok", false)) or mid == "":
			out["careSupported"] = false
			out["reason"] = "Aún no hay pieza: hay que hacerla en el horno (o comprarla) y dejarla enfriar."
			return out
		if not ClawCare.supports_block(mid):
			out["careSupported"] = false
			out["reason"] = "La cetrería aún no conoce este material: no está en el catálogo del banco."
			return out
		var nm := String(ForgeData.inlay_entry(mid).name).to_lower()
		out["piece"] = _piece_for_care()
		if ForgeData.PROSTHESIS.has(mid):
			# la prótesis de verdad (unidad 5j): el acrílico dental sobre el muñón, limado en el animal
			var pe: Dictionary = ForgeData.PROSTHESIS[mid]
			out["block"] = {
				"material": mid, "stump_mm": maxf(float(from_care.stump_mm), 0.0), "wall_mm": _wall_mm, "fiction": false,
				"quality": String(pe.use_quality),
				"note": "Así se repara de verdad: el %s se aplica sobre lo que queda de la garra con algo de sobra, fragua en frío y se lima en el animal hasta la forma de la natural, con una lima o una amoladora; se rehace cuando la garra crece por debajo. Es la técnica del pico de las aves; en una garra, la misma (estimación)." % nm,
				"source": String(pe.use_source),
			}
			return out
		out["block"] = {
			"material": mid, "stump_mm": maxf(float(from_care.stump_mm), 0.0), "wall_mm": _wall_mm, "fiction": true, "quality": "ficcion",
			"note": "FICCIÓN: un bloque de %s pegado al muñón y limado en el animal. En la realidad la funda o la prótesis se talla aparte (con muelas y discos de diamante y agua, horas en las gemas) y se pega en frío ya terminada, como una corona dental o la prótesis del pico de una rapaz; en el animal solo se pega y se lima una prótesis de acrílico dental, la vía real. %s" % [nm, _block_heat_words(mid)],
			"source": ForgeData.ADHESIVES.metacrilato.source,
		}
		return out
	var rc := result_claw()
	var inl := String(rc.inlay)
	if inl == "none" or not bool(rc.ok):
		return out
	if ClawCare.supports_inlay(inl):
		out["inlay"] = inl
	else:
		out["careSupported"] = false
		out["reason"] = "La cetrería aún no conoce este material (%s): no está en el catálogo del banco." % String(rc.name).to_lower()
	# la pieza sin pegar (5m; petición 43): lo que necesitará la cetrería para colocarla y acabarla a mano
	out["piece"] = _piece_for_care()
	return out


## La pieza sin pegar para la cetrería (5m; petición 43: allí se coloca y se acaba a mano): { material, ok, finish, carved,
## polished, coverMm, wallMm, wallLeftMm, lengthMm, bondAreaMm2 (la superficie que se pega), gapMm (la holgura de la prueba del
## ajuste o, sin probarla, la ideal del epoxi), fitTested, massKg, raUm, castScale }; {} sin pieza.
func _piece_for_care() -> Dictionary:
	if _piece.is_empty():
		return {}
	var rho: Variant = ForgeData.density_of(String(_piece.get("material", "")))
	return {
		"material": String(_piece.get("material", "")), "ok": bool(_piece.get("ok", false)), "finish": String(_piece.get("finish", "")),
		"carved": bool(_piece.get("carved", false)), "polished": bool(_polish.get("ok", false)), "coverMm": float(_sheath.coverMm),
		"wallMm": _wall_mm, "wallLeftMm": float(_cut.get("wallLeftMm", _wall_mm)), "lengthMm": float(_sheath.lengthMm),
		"bondAreaMm2": float(_sheath.innerAreaMm2), "gapMm": float(_fit.get("gapMm", float(ForgeData.ADHESIVES.epoxi.gap_ideal))),
		"fitTested": bool(_fit.get("ok", false)), "massKg": float(rho) * float(_sheath.volumeMm3) * 1.0e-9 if rho != null else 0.0,
		"raUm": float(_surf.get("raUm", 0.0)), "castScale": float((_piece.get("cast", {}) as Dictionary).get("scale", 1.0)),
		# 5r · la unión soldada (null sin soldar): el método, la otra pieza, lo que aguanta (MPa) frente al metal base y su color
		"weld": (_piece.weld as Dictionary).duplicate(true) if _piece.has("weld") else null,
	}


## Cómo cuenta la cetrería el calor de limar un bloque de este material (unidad 5j): con su conducción, o como la queratina
## si su ficha no la trae (ClawCare.block_thermal).
static func _block_heat_words(mid: String) -> String:
	if ClawCare.block_thermal(mid).is_empty():
		return "Sin datos de cómo conduce el calor: el de limarlo se cuenta como en la queratina."
	return "El calor de limarlo se cuenta con la conducción de su material: en un metal o una cerámica llega antes a la carne viva que en la queratina."


## Etapa en la que está el proceso (la primera que falta). Desde la 5m (petición 43) acaba en la pieza pulida: pegarla y probarla
## con la carga son de la cetrería, sobre el animal.
func stage() -> String:
	if bool(_coat.get("fiction", false)) and bool(_coat.get("ok", false)):
		return "pulir" if _polish.is_empty() else "hecho"
	if _piece.is_empty() or not bool(_piece.get("ok", false)):
		return "material" if _recipe.is_empty() else "horno"
	if _cooled.is_empty():
		return "enfriar"
	if not bool(_piece.get("carved", false)) and not bool(_coat.get("fiction", false)):
		return "tallar"
	if _barrier.is_empty():
		return "proteger"
	if _polish.is_empty() or not bool(_polish.get("ok", false)):
		return "pulir"
	return "hecho"


## Instantánea para la escena y la interfaz (diccionario nuevo en cada llamada).
func snapshot() -> Dictionary:
	return {
		"serial": _serial, "stage": stage(), "animal_id": String(_animal.id), "claw_id": String(_claw.id), "recipe": String(_recipe.get("id", "")),
		"sheath": _sheath.duplicate(true), "mix": _mix_eval.duplicate(true), "fire": _fire.duplicate(true), "piece": _piece.duplicate(true),
		"cooled": _cooled.duplicate(true), "carved": _carved.duplicate(true), "barrier": _barrier.duplicate(true), "coat": _coat.duplicate(true),
		"bond": _bond.duplicate(true), "polish": _polish.duplicate(true), "check": _check.duplicate(true), "fiction": _fiction.duplicate(),
		"events": _events.duplicate(true), "liveWallMm": live_wall_mm(), "furnace": ForgeData.FURNACE.duplicate(true),
		"surface": surface(), "loaded": loaded(), "wax": _wax.duplicate(true), "invest": _invest.duplicate(true),
		"burnout": _burnout.duplicate(true), "divest": _divest.duplicate(true), "cut": carve_state(), "fit": _fit.duplicate(true),
		"castable": castable(_recipe, String(_piece.get("material", "")) if _recipe.is_empty() else ""), "weld": weld_state(),
	}


const VERDICTS := {
	"bien": "Funda terminada: hecha, tallada y pulida, lista para colocarla en la cetrería.",
	"agujereada": "Se talló de más y la pared de la funda se agujereó.",
	"ficcion": "FICCIÓN: garra viva recubierta sin quemarla. En la realidad se haría una funda aparte.",
	"astillada": "Se astilló al tallarla.",
	"quemada": "Se oxidó, se quemó o se volvió grafito.",
	"no_funde": "No llegó a fundir o a crecer: sin cristal ni colada.",
	"no_cabe": "La funda no cabe en el cristal que da este método: hay que cubrir menos garra o usar otro material.",
	"agrietada": "Se agrietó al enfriar (choque térmico, sin recocer o la inversión del cuarzo).",
	"despega": "La funda se despega con la carga: la unión no aguanta.",
	"defectuosa": "Sale con defectos: poros, burbujas, deformada, o con la mezcla, el modo o el molde equivocados.",
	"garra_quemada": "La garra viva se quema o se lesiona: lo caliente se hace aparte, como una funda (y en la realidad no se recubre una garra viva).",
	"soldadura_mala": "La soldadura ha fallado: la unión se ha perforado, contaminado o agrietado, o la plata no ha mojado.",
	"incompleta": "El proceso no ha terminado.",
}


## Veredicto del proceso con su texto y consejos: { verdict, verdictText, quality, finish, facts, advice [{ text, source }],
## fiction }. Manda lo primero que salió mal, en el orden del proceso.
func report() -> Dictionary:
	var v := "incompleta"
	var adv: Array = []
	var fd := String(_fire.get("defect", ""))
	var cd := String(_cooled.get("defect", ""))
	var kd := String(_carved.get("defect", ""))
	var pd := String(_piece.get("defect", ""))
	var fin := String(_piece.get("finish", ""))
	if String(_coat.get("defect", "")) in ["garra_quemada", "carne_lesionada", "barrera_falla"]:
		v = "garra_quemada"
		adv.append({ "text": "Lo caliente se hace aparte: una funda colada, sinterizada o tallada, pegada en frío.", "source": String(CareData.THERMAL.char_c.source) })
	elif bool(_coat.get("fiction", false)) and bool(_coat.get("ok", false)):
		v = "ficcion"
	elif fin == "quemado":
		v = "quemada"
	elif fd == "tamano":
		v = "no_cabe"
	elif fd == "presion" or (fd == "frio" and fin != "poroso"):
		v = "no_funde"
	elif fd != "" or pd in ["funde", "reblandece"]:
		v = "defectuosa"
	elif cd in ["choque", "sin_recocer", "inversion"]:
		v = "agrietada"
	elif kd in ["astilla", "grieta_calor"]:
		v = "astillada"
	elif kd == "agujero":
		v = "agujereada"
	elif pd.begins_with("soldadura_"):
		v = "soldadura_mala"
		adv.append({ "text": String(_piece.get("text", "")), "source": String((_piece.get("weld", {}) as Dictionary).get("source", "")) })
	elif bool(_check.get("detached", false)) and not _check.is_empty():
		v = "despega"
	elif _finished():
		v = "bien"
	if kd == "no_muerde" or String(_polish.get("defect", "")) == "no_muerde":
		adv.append({ "text": "El abrasivo tiene que ser más duro que la pieza: diamante para el zafiro, el diamante y el metal duro.", "source": ForgeData.SRC_FILE_TEST })
	if fd != "":
		adv.append({ "text": String(_fire.text), "source": String(_recipe.get("source", "")) })
	if cd != "":
		adv.append({ "text": "Enfría dentro del horno: el salto brusco agrieta lo frágil.", "source": ForgeData.SRC_KINGERY + "; " + ForgeData.SRC_MANSON })
	if v == "despega":
		adv.append({ "text": "Cubre más superficie, usa una holgura dentro de la del adhesivo y pega la garra seca.", "source": ForgeData.SRC_LOCTITE_GUIDE })
	var rc := result_claw()
	return {
		"verdict": v, "verdictText": String(VERDICTS[v]), "quality": "ficcion" if v in ["ficcion", "garra_quemada"] else String(_piece.get("quality", "")),
		"finish": String(rc.finish), "facts": { "sheath": _sheath.duplicate(true), "claw": rc }, "advice": adv, "fiction": _fiction.duplicate(),
	}


## La máquina que trabaja con el modo `mode` del horno (el selector) y la receta `rec` (cada modo es una máquina real):
## «verneuil», «hpht» o «cvd» al sintetizar (la del método de la receta; sin receta de síntesis, el soplete de Verneuil),
## «sinterizado», «induccion», «colada» (fundir y colar) o «calentar» (el horno eléctrico). La usan el sonido de la marcha
## (sfx_for) y la animación del estado (ClawForgeState): las dos siguen a la máquina de verdad, no a la receta.
static func machine_for(mode: String, rec: Dictionary = {}) -> String:
	match mode:
		"sintetizar":
			var m := String(rec.get("method", ""))
			return m if m in ["verneuil", "hpht", "cvd"] else "verneuil"
		"sinterizar":
			return "sinterizado"
		"induccion":
			return "induccion"
		"fundir_colar":
			return "colada"
	return "calentar"


## El bucle de una máquina en marcha (SFX_FORGE; diseño de sonido, no datos): la llama del soplete de Verneuil, la prensa
## del HPHT, la bobina de inducción o el zumbido del horno eléctrico (al sinterizar, fundir y colar, calentar y en la CVD).
static func machine_sfx(machine: String) -> String:
	match machine:
		"verneuil":
			return "forja-llama"
		"hpht":
			return "forja-prensa"
		"induccion":
			return "forja-induccion"
	return "forja-horno"


## Efecto de sonido de una acción: «fire» (la máquina del modo con que ha trabajado el horno, aunque no sea el de la
## receta: llama, prensa, inducción u horno; sin marcha aún, la de la receta), «heat» (calentar una pieza: el horno),
## «pour» (colar), «cool» (temple en agua o aceite: siseo; grieta: shatter), «carve» (muela; astilla: snap; no muerde:
## slide), «polish», «coat» (la garra que se quema sisea como el temple). Los ids «forja-…» son nuevos (SFX_FORGE, para la
## parte de interfaz); los demás, los del laboratorio.
func sfx_for(action: String, result: Dictionary) -> String:
	match action:
		"fire":
			var params: Dictionary = result.get("params", _fire.get("params", {}))
			return machine_sfx(machine_for(String(params.get("mode", _recipe.get("mode", ""))), _recipe))
		"heat":
			return machine_sfx("calentar")
		"pour":
			return "forja-colada"
		"cool":
			if String(result.get("defect", "")) in ["choque", "inversion", "sin_recocer"]:
				return "shatter"
			return "forja-temple" if String(result.get("medium", "")) in ["agua", "aceite"] else "tap"
		"carve":
			if bool(result.get("chipped", false)) or String(result.get("defect", "")) == "grieta_calor":
				return "snap"
			if not bool(result.get("bites", true)):
				return "slide"
			return "forja-muela"
		"polish":
			if not bool(result.get("bites", true)):
				return "slide"
			var surf := String(result.get("surface", ""))
			return "scratch-metal" if surf in ["cromo", "tin"] or ForgeData.MATERIALS.get(surf, {}).get("family", "") == "metal" else "scratch-glass"
		"coat":
			return "forja-temple" if String(result.get("defect", "")) == "garra_quemada" else "forja-horno"
		"weld_pulse":
			# 5r · cada pulso: el clic del láser («forja-pulso»), el chasquido del arco («forja-arco»); el soplete suena en bucle
			# (la llama, ClawForgeState.sound_view) y un pulso que no cuenta no suena
			if not bool(result.get("ok", false)):
				return ""
			match String(result.get("method", "")):
				"laser":
					return "forja-pulso"
				"tig":
					return "forja-arco"
			return ""
	return "tap"


## Condiciones del tutorial (claw_forge_tutorial.gd).
const CHECK_KEYS := ["mezcla_ok", "modo_ok", "parametros_ok", "pieza_ok", "enfriada", "tallada", "muela_adecuada", "protegida", "recubierta", "unida", "pulida", "comprobada", "sin_quemar",
	"dentro", "cera", "revestido", "quemada", "desmoldada", "tocho", "desbastada", "vaciada", "ajuste",
	"soldadura_lista", "alineada", "soldada", "costura_limada"]


func check(key: String) -> bool:
	match key:
		"dentro":
			# la carga en la máquina del modo de la receta (o ya hecha la marcha)
			return not _fire.is_empty() or (not _loaded.is_empty() and String(_loaded.machine) == machine_for(String(_recipe.get("mode", "")), _recipe))
		"cera":
			return bool(_wax.get("ok", false))
		"revestido":
			return bool(_invest.get("ok", false))
		"quemada":
			return bool(_burnout.get("ok", false))
		"desmoldada":
			return bool(_piece.get("divested", false))
		"tocho":
			return bool(_piece.get("carved", false)) or (not _cut.is_empty() and int(_cut.cuts) >= int(_cut.cutsNeed))
		"desbastada":
			return bool(_piece.get("carved", false)) or (not _cut.is_empty() and int(_cut.cuts) >= int(_cut.cutsNeed) and not _carve_goal_left("muela_gruesa"))
		"vaciada":
			return bool(_piece.get("carved", false)) or (not _cut.is_empty() and not _carve_goal_left("fresa"))
		"ajuste":
			return bool(_fit.get("ok", false))
		"soldadura_lista":
			return bool(_weld.get("ok", false))
		"alineada":
			return bool(_weld.get("ok", false)) and bool(_weld.get("aligned", false))
		"soldada":
			return bool((_weld.get("joint", {}) as Dictionary).get("ok", false))
		"costura_limada":
			return _piece.has("weld") and bool((_piece.weld as Dictionary).get("ok", false)) and (_cut.is_empty() or float(_cut.get("seamMm", 0.0)) <= 0.0)
		"mezcla_ok":
			return bool(_mix_eval.get("ok", false))
		"modo_ok":
			return not _fire.is_empty() and String(_fire.params.get("mode", "")) == String(_recipe.get("mode", ""))
		"parametros_ok":
			return bool(_fire.get("ok", false))
		"pieza_ok":
			return bool(_piece.get("ok", false))
		"enfriada":
			return bool(_cooled.get("ok", false))
		"tallada":
			return bool(_piece.get("carved", false)) and bool(_piece.get("ok", false))
		"muela_adecuada":
			return bool(_carved.get("bites", false))
		"protegida":
			return bool(_barrier.get("ok", false))
		"recubierta":
			return bool(_coat.get("ok", false))
		"unida":
			return bool(_bond.get("ok", false))
		"pulida":
			return bool(_polish.get("ok", false))
		"comprobada":
			return bool(_check.get("ok", false))
		"sin_quemar":
			return not bool((_coat.get("thermal", {}) if _coat.get("thermal") != null else {}).get("charred", false))
	return true


## El tutorial de una receta para este proceso (o el general del horno, «horno»): pasos con done y, en los que tienen
## acción, los argumentos recomendados (args).
func tutorial(rid: String = "") -> Array:
	var id := rid if rid != "" else String(_recipe.get("id", "horno"))
	var rec := recommended(id)
	var out: Array = []
	for st: Dictionary in Tutorial.steps(id):
		var s2 := st.duplicate(true)
		s2["done"] = check(String(st.check)) if String(st.check) != "" else null
		var base: Variant = rec.get(String(st.action), null)
		# un paso puede traer lo suyo encima de lo recomendado (la herramienta de cada pasada, 5m)
		if st.get("step_args") is Dictionary:
			var merged: Dictionary = (base as Dictionary).duplicate(true) if base is Dictionary else {}
			merged.merge(st.step_args, true)
			s2["args"] = merged
		else:
			s2["args"] = base
		s2.erase("step_args")
		out.append(s2)
	return out


## Lo que recomienda la receta para esta garra, por acción: { mix: { polvo: g }, fire: {...}, cool: medio, carve, protect,
## bond, polish, check_load }. El tiempo del horno es el que pide la funda (el crecimiento o el sinterizado) con un 10 % de
## margen, y nunca menos que el de la receta. {} sin receta.
func recommended(rid: String = "") -> Dictionary:
	if rid == Tutorial.WELD:
		return weld_recommended()
	if rid == Tutorial.ACRYLIC:
		# la prótesis de verdad (unidad 5j): mezclar el acrílico; se aplica y se lima en la cetrería
		return { "choose": Tutorial.ACRYLIC }
	if rid == Tutorial.STONE:
		return {
			"choose": Tutorial.STONE_DEFAULT,
			"carve": { "abrasive": "diamante", "coolant": true, "force_n": float(ForgeData.CARVE_DEFAULTS.force_n), "speed_ms": float(ForgeData.CARVE_DEFAULTS.speed_ms) },
			"carve_to": { "abrasive": "diamante", "coolant": true, "force_n": float(ForgeData.CARVE_DEFAULTS.force_n) },
			"protect": { "barrier": "aerogel", "thickness_mm": 3.0 },
			"bond": { "adhesive": "epoxi", "gap_mm": float(ForgeData.ADHESIVES.epoxi.gap_ideal) },
			"fit": { "gap_mm": float(ForgeData.ADHESIVES.epoxi.gap_ideal) },
			"polish": { "abrasive": "diamante", "grain_um": 9.0 },
			"check_load": {},
		}
	if rid == Tutorial.LIVE:
		# FICCIÓN: la alúmina por plasma con la garra a ~150 °C, 30 s, solo en la mitad de la punta muerta y con la carne viva
		# tapada; y pulir con diamante
		return {
			"protect": { "barrier": "aerogel", "thickness_mm": 3.0 },
			"coat": { "method": "plasma_alumina", "target": "garra_viva", "time_s": 30.0, "cover_mm": 0.5 * float(_care.quick_cover_mm()) },
			"polish": { "abrasive": "diamante", "grain_um": 9.0 },
		}
	var r := ForgeData.recipe(rid if rid != "" else String(_recipe.get("id", "")))
	if r.is_empty():
		return {}
	var grams := {}
	for p: Dictionary in r.powders:
		grams[p.id] = float(p.value) * 100.0
	var fp := {
		"mode": String(r.mode), "temp_c": float(r.temp_c.value), "atmosphere": String(r.atmosphere.value),
		"pressure_mpa": float(r.pressure_mpa.value), "time_s": float(r.time_s.value),
	}
	if r.has("mold"):
		fp["mold"] = String(r.mold.value)
	if r.has("methane"):
		fp["methane"] = float(r.methane.value)
	var probe := evaluate_fire(r, evaluate_mix(r, grams), fp, _sheath)
	fp["time_s"] = maxf(float(r.time_s.value), ceilf(float(probe.timeNeedS) * 1.1))
	var ferrous := bool(ForgeData.material(String(r.product)).get("ferrous", false))
	var machine := machine_for(String(r.mode), r)
	var out := {
		"mix": grams, "fire": fp, "cool": String(r.cool.value),
		"load_machine": { "machine": machine, "what": charge_for(machine) },
		"carve": { "abrasive": "cbn" if ferrous else "diamante", "coolant": true, "force_n": float(ForgeData.CARVE_DEFAULTS.force_n), "speed_ms": float(ForgeData.CARVE_DEFAULTS.speed_ms) },
		"carve_to": { "abrasive": "cbn" if ferrous else "diamante", "coolant": true, "force_n": float(ForgeData.CARVE_DEFAULTS.force_n) },
		"protect": { "barrier": "aerogel", "thickness_mm": 3.0 },
		"bond": { "adhesive": "epoxi", "gap_mm": float(ForgeData.ADHESIVES.epoxi.gap_ideal) },
		"fit": { "gap_mm": float(ForgeData.ADHESIVES.epoxi.gap_ideal) },
		"polish": { "abrasive": "diamante", "grain_um": 9.0 },
		"check_load": {},
	}
	# la cera perdida de los metales y el vidrio (5m): su revestimiento y su ciclo de quemado
	if String(r.form) == "colada" and r.has("mold"):
		var mold := String(r.mold.value)
		var b: Dictionary = ForgeData.BURNOUT.get("vidrio" if String(r.product) == "vidrio" and mold == "yeso" else mold, {})
		out["wax"] = { "compensate": true, "mold": mold }
		out["invest"] = { "mold": mold }
		out["burnout"] = { "temp_c": float(b.get("top_c", 0.0)), "time_s": float(b.get("top_hold_s", 0.0)) }
		out["divest"] = {}
	return out


## Lo que recomienda la mesa de soldar para la pieza de ahora (5r): el oro refleja el láser frío (se suelda con el micro-TIG);
## el acero y el titanio, con el láser (el titanio, con argón); el metal duro, solo con soldadura fuerte. Los mandos, los que
## atraviesan la pared de serie sin perforarla (los casos de referencia de tests/lab/test_claw_weld.gd). Después, limar el
## cordón con la muela fina y pulir.
func weld_recommended() -> Dictionary:
	var mid := String(_piece.get("material", ""))
	var ferrous := bool(ForgeData.material(mid).get("ferrous", false))
	var setup := {}
	match mid:
		"oro":
			setup = { "method": "tig", "part": "punta", "material": "oro", "current_a": 400.0, "pulse_ms": 12.0, "gas": "argon", "overlap": 0.85 }
		"titanio":
			setup = { "method": "laser", "part": "punta", "material": "titanio", "energy_j": 25.0, "pulse_ms": 5.0, "spot_mm": 0.8, "gas": "argon", "overlap": 0.65 }
		"tungsteno":
			setup = { "method": "braze", "part": "punta", "material": "tungsteno", "temp_c": 700.0, "gap_mm": 0.04 }
		_:
			setup = { "method": "laser", "part": "punta", "material": mid if mid != "" else "acero", "energy_j": 30.0, "pulse_ms": 4.0, "spot_mm": 0.6, "gas": "argon", "overlap": 0.65 }
	_weld_fit_power(setup, mid)
	return {
		"weld_setup": setup, "weld_align": 0.0, "weld_pulse": {},
		"carve_to": { "abrasive": "cbn" if ferrous else "diamante", "coolant": true, "force_n": float(ForgeData.CARVE_DEFAULTS.force_n) },
		"polish": { "abrasive": "diamante", "grain_um": 9.0 },
	}


## La energía (láser) o la corriente (micro-TIG) más baja del mando que, con la pared de esta funda, atraviesa la pared sin
## perforarla (ClawWeld.seam: through y no perforated), con el solape de resistencia y, si no basta, con el de estanca. Cambia
## setup en su sitio; si nada lo consigue, lo deja como estaba (el motor lo explicará al soldar). Sin física nueva: la de
## ClawWeld con los mandos y sus pasos.
func _weld_fit_power(setup: Dictionary, mid: String) -> void:
	var method := String(setup.method)
	if method == "braze" or mid == "":
		return
	var key := "energy_j" if method == "laser" else "current_a"
	var cd: Dictionary = ClawWeld.METHODS[method].controls[key]
	var length := float(weld_seam_geometry().lengthMm)
	for ov: float in [0.65, 0.85]:
		var x := float(cd.min)
		while x <= float(cd.max) + 1e-9:
			var spot := ClawWeld.laser_spot(mid, x, float(setup.pulse_ms), float(setup.spot_mm), "argon") if method == "laser" else ClawWeld.tig_spot(mid, x, float(setup.pulse_ms), "argon")
			if bool(spot.get("ok", false)):
				var sm := ClawWeld.seam(spot, _wall_mm, length, ov)
				if bool(sm.get("through", false)) and not bool(sm.get("perforated", false)):
					setup[key] = x
					setup["overlap"] = ov
					return
			x += float(cd.step)


## Hace un paso del tutorial con sus argumentos (la acción y los args de tutorial()). Devuelve el resultado de la acción.
func do_step(step: Dictionary) -> Variant:
	var args: Variant = step.get("args")
	match String(step.get("action", "")):
		"mix":
			return mix(args)
		"fire":
			return fire(args)
		"cool":
			return cool(String(args))
		"carve":
			return carve(args)
		"choose":
			return choose(String(args))
		"protect":
			return protect(args)
		"coat":
			return coat(args)
		"bond":
			return bond(args)
		"polish":
			return polish(args)
		"check_load":
			return check_load(args if args != null else {})
		"load_machine":
			return load_machine(args)
		"wax":
			return wax(args if args != null else {})
		"invest":
			return invest(args if args != null else {})
		"burnout":
			return burnout(args)
		"divest":
			return divest()
		"carve_to":
			return carve_to(args)
		"fit":
			return fit(args if args != null else {})
		"weld_setup":
			return weld_setup(args if args != null else {})
		"weld_align":
			return weld_align(float(args) if args != null else 0.0)
		"weld_pulse":
			return weld_pulse(args if args != null else {})
		"weld_finish":
			return weld_finish()
	return null
