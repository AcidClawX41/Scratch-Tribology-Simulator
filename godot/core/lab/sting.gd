## Tribología biológica · física de los aguijones (modelo 2.0; no existe en el motor 1.x).
##
## Funciones puras, estáticas y deterministas. Reutilizan la capa compartida (contact.gd) y las funciones de piel y de
## dureza de physics.gd; no copian sus fórmulas. Modelo, fuentes y guía de integración: docs/fisica/aguijones.md.
##
##   1. Perforar la piel. El ajuste de Davis 2004 (physics.gd) se midió con puntas de 30-80 µm: por debajo de 0,08 N
##      es una extrapolación, y con la punta de 1 µm de una abeja pediría 80 mN (hasta 60 veces lo medido, 1,3-5,8 mN).
##      Una punta afilada abre una grieta plana en modo I que avanza con ella (Shergold & Fleck 2005): la energía por
##      unidad de avance es la tenacidad al corte por la anchura de la grieta, F = 2·J·a, la misma relación que usa
##      physics.gd para seguir entrando. Al principio a es el radio de la punta: F_p = máx(2·J_córnea·R_punta, Davis),
##      y Davis solo dentro de su rango. Para todas las uñas, garras y colmillos del banco manda Davis: nada cambia.
##   2. Entrar. Un aguijón no se clava empujando: las dos lancetas avanzan por turnos, cada una anclada por sus púas
##      mientras la otra corta (Ramirez-Esquivel 2023). Rota la piel, llega hasta el bulbo (reach), que nunca entra.
##      El empuje del insecto solo sirve para perforar la superficie.
##   3. Pandeo. Antes de perforar, el aguijón es una columna hueca empotrada en el bulbo y con la punta libre sobre la
##      piel (voladizo, K = 2): Euler, o Johnson si la columna es corta para su límite elástico (Y = H/2,8, Tabor, la
##      misma relación que usa contact.gd). El módulo de un aguijón natural cambia de la base a la punta (Das 2018); se
##      pondera con el modo de pandeo (Rayleigh), así que manda la base. Un aguijón «reforjado» toma el E y la dureza
##      de su material y conserva la geometría.
##   4. Anclaje de las púas. Una púa de altura b obliga al agujero de diámetro D a estirarse ε = 2b/(πD) para dejarla
##      pasar. Si el tejido lo recupera elásticamente (la piel aguanta un 54 %, Ní Annaidh 2012), se cierra detrás y la
##      engancha. Si no (la cutícula de un insecto o un sólido dúctil del banco: ~Y/E, un 0,3-5 %; un frágil, nada), la
##      púa talla un surco que no se cierra y el aguijón sale por él. La fuerza para arrancarlo es J_anclaje·Σpúas
##      (calibrada con la abeja, Ling 2016-2017).
##   5. Se queda clavado si engancha y las púas son grandes y no se pueden enfundar: la regla empírica de 51 especies
##      (Bissessarsingh & Starr 2021: Sr ≥ 1 u 8 púas o más) más el estilete que enfunda las púas de los véspidos
##      (Mulfinger 1992). La abeja pierde entonces el aparato del aguijón (autotomía): es de su anatomía, no de la aguja.
##   6. Sólidos. Manda la dureza de siempre (r = HV_punta/HV_objetivo, FISICA.md §4), pero a la escala de la punta: la
##      madera es blanda en bloque (Janka) y dura en sus paredes celulares (nanoindentación, ~0,45 GPa).
## Unidades: fuerza N (la interfaz la enseña en mN), longitud mm (µm donde se dice), E en GPa, dureza HV, tiempo s.
## Uso: const Sting = preload("res://core/lab/sting.gd").
extends RefCounted

const Js = preload("res://core/shared/js.gd")
const V8 = preload("res://core/shared/v8_math.gd")
const Contact = preload("res://core/shared/contact.gd")
const Data = preload("res://core/lab/data.gd")
const Physics = preload("res://core/lab/physics.gd")
const Insects = preload("res://core/lab/insects.gd")

const HV_MPA := Contact.HV_MPA
## Gravedad (m/s²): la misma con la que 1 kgf son 9,807 N (HV_MPA).
const G := 9.807
## Longitud efectiva de pandeo = 2·L: base empotrada en el bulbo, punta libre sobre la piel (voladizo).
const CANTILEVER_K := 2.0
## Constantes del modelo de aguijones (fuentes y razonamiento: docs/fisica/aguijones.md).
const MODEL := {
	"cantileverK": CANTILEVER_K,  # voladizo: con la punta ya clavada sería K ≈ 0,7 (hasta ×8 de carga)
	"anchorJ": 0.61,  # N/mm (= kJ/m²) · tenacidad efectiva de anclaje de las púas en la piel (calibrada: Ling 2016-2017)
	"skinRecoverableStrain": 0.54,  # deformación de rotura media de la piel humana (Ní Annaidh 2012)
	"srStuck": 1.0,  # índice de serrado a partir del cual la autotomía es probable (Bissessarsingh & Starr 2021)
	"barbsStuck": 8,  # púas por lanceta a partir de las que la autotomía es probable (ídem)
	"markRatio": 1.25,  # r por debajo del cual solo hay pulido mutuo (Richardson 1968; FISICA.md §4)
}
## Pesos del modo de pandeo de un voladizo, y = 1 − cos(πx/2L) con x desde la base, para los tercios basal, medio y
## apical: ∫cos²(πx/2L) en cada tercio dividido por ∫₀ᴸ = L/2 (1/3 + √3/2π, 1/3, 1/3 − √3/2π).
const BUCKLE_W_BASE := 0.60899778104423
const BUCKLE_W_MID := 0.33333333333333
const BUCKLE_W_TIP := 0.057668885622436
## Dureza a la escala de la punta de un aguijón (1-5 µm) en los objetivos celulares: la de la pared de la célula.
## Pared S2 de traqueidas de abeto: 0,427 GPa con punta cónica y 0,477 con Berkovich → 0,45 GPa = 45,9 HV.
const CELL_WALL := {
	"madera": { "hv": 45.9, "source": "Konnerth J, Gierlinger N, Keckes J, Gindl W (2009). J. Mater. Sci. 44:4399-4406, doi:10.1007/s10853-009-3665-7 (abeto; el pino es otra conífera con traqueidas parecidas)", "quality": "secondary" },
	"puertamadera": { "hv": 45.9, "source": "estimación: la misma pared celular para el roble (sin medición propia)", "quality": "estimate" },
}
## Cutícula esclerotizada de insecto, como referencia de anclaje (no es un objetivo del banco 1.x): dureza de la base
## de un aguijón (0,42 GPa, Das 2018) y módulo de la cutícula fresca de la tibia de langosta (3,05 GPa, Dirks & Taylor
## 2012, J. Exp. Biol. 215:1502, doi:10.1242/jeb.068221). Límite elástico ≈ Y/E = (H/2,8)/E ≈ 4,9 %.
const CUTICLE := {
	"id": "cuticula", "name": "Cutícula de insecto", "hv": 42.8, "E": 3.05, "mu": 0.3, "W": 0.02,
	"source": "Das et al. 2018 (dureza); Dirks & Taylor 2012 (módulo)", "quality": "secondary",
}


# ── Lectura de datos ──

## Valor de un dato del bloque `stinger` ({ value, source, quality }), o null.
static func sval(st: Dictionary, key: String) -> Variant:
	var d: Variant = st.get(key)
	return d.get("value") if d is Dictionary else null


## ¿La herramienta es un aguijón reforjado en otro material (incrustación)?
static func is_reforged(inlay: Variant) -> bool:
	return Js.truthy(inlay) and inlay.id != "none"


# ── 1 · Perforar la piel ──

## Radio de la esfera de la punta (mm) para un área de punta (mm²): el mismo R = √(A/π) de contact.gd.
static func tip_radius_mm(area_mm2: float) -> float:
	return Contact.tip_geometry(area_mm2, 0.0)["R"]


## Fuerza (N) para romper la superficie de la piel con una punta de área A (mm²). stack: capas de la piel.
##   - Fractura: F = 2·J·R_punta, con la tenacidad al corte de la capa de arriba (Shergold & Fleck 2005).
##   - Davis 2004 (Physics.skin_puncture_force), solo donde su ajuste es válido (por encima de su mínimo medido).
static func puncture_force(area_mm2: float, stack: Array = Data.SKIN_LAYERS) -> float:
	return maxf(fracture_puncture_force(area_mm2, stack), davis_in_range(area_mm2))


## Término de fractura de la perforación (N): la grieta plana de la anchura de la punta.
static func fracture_puncture_force(area_mm2: float, stack: Array = Data.SKIN_LAYERS) -> float:
	var jc: float = stack[0].jC  # kJ/m² = N/mm
	return 2.0 * jc * tip_radius_mm(area_mm2)


## Ajuste de Davis 2004 si la punta está en su rango, o 0: su mínimo (0,08 N) es el borde de lo medido, no un suelo físico.
static func davis_in_range(area_mm2: float) -> float:
	var f := Physics.skin_puncture_force(area_mm2)
	return f if f > Physics.MODEL.skinPunctureMin else 0.0


## Qué término manda en la perforación: "fractura" (puntas finas: aguijones) o "davis" (uñas, garras, colmillos).
static func puncture_regime(area_mm2: float, stack: Array = Data.SKIN_LAYERS) -> String:
	return "davis" if davis_in_range(area_mm2) > fracture_puncture_force(area_mm2, stack) else "fractura"


# ── 3 · Pandeo ──

## Sección del aguijón como tubo hueco (el canal del veneno): { D, Di (mm), I (mm⁴), A (mm²), rg (mm) }.
static func section(st: Dictionary) -> Dictionary:
	var d: float = float(sval(st, "diameterUm")) / 1000.0
	var di: float = float(sval(st, "canalUm")) / 1000.0
	var i := PI / 64.0 * (d * d * d * d - di * di * di * di)
	var a := PI / 4.0 * (d * d - di * di)
	return { "D": d, "Di": di, "I": i, "A": a, "rg": sqrt(i / a) }


## Módulo efectivo (GPa) de un aguijón con gradiente (tercios basal, medio y apical), ponderado con el modo de pandeo.
static func graded_modulus(mat: Dictionary) -> float:
	return BUCKLE_W_BASE * float(mat.base.E) + BUCKLE_W_MID * float(mat.mid.E) + BUCKLE_W_TIP * float(mat.tip.E)


## Límite elástico (MPa) a partir de la dureza (HV): Y = H/2,8 (Tabor, CONTACT.tabor).
static func yield_from_hv(hv: float) -> float:
	return hv * HV_MPA / Contact.CONTACT["tabor"]


## Material de la columna: el natural (quitina con gradiente) o el de la incrustación. { E (GPa), yield (MPa), id }.
static func column_material(claw: Dictionary, inlay: Variant = null) -> Dictionary:
	if is_reforged(inlay):
		return { "E": float(inlay.E), "yield": yield_from_hv(inlay.hv), "id": String(inlay.id) }
	var mat: Dictionary = claw.stinger.material
	return { "E": graded_modulus(mat), "yield": float(mat.base.H) * 1000.0 / Contact.CONTACT["tabor"], "id": "quitina" }


## Carga de pandeo (N) de una columna hueca: Euler, o la parábola de Johnson si la esbeltez λ es menor que la de
## transición λc = π·√(2E/Y). E en GPa, Y en MPa, L en mm. { F, mode: "euler" | "johnson", lambda, lambdaC }.
static func buckling_load(e_gpa: float, yield_mpa: float, sec: Dictionary, length_mm: float, k: float = CANTILEVER_K) -> Dictionary:
	var e := e_gpa * 1000.0  # MPa = N/mm²
	var le := k * length_mm
	var lam: float = le / sec.rg
	var lam_c := PI * sqrt(2.0 * e / yield_mpa)
	if lam >= lam_c:
		return { "F": PI * PI * e * sec.I / (le * le), "mode": "euler", "lambda": lam, "lambdaC": lam_c }
	var sigma := yield_mpa * (1.0 - lam * lam / (2.0 * lam_c * lam_c))
	return { "F": sigma * sec.A, "mode": "johnson", "lambda": lam, "lambdaC": lam_c }


## Pandeo del aguijón entero (longitud libre = reach) en su material natural o reforjado.
static func buckling(claw: Dictionary, inlay: Variant = null) -> Dictionary:
	var m := column_material(claw, inlay)
	return buckling_load(m.E, m.yield, section(claw.stinger), float(claw.reach))


# ── 6 · Durezas a la escala de la punta ──

## Dureza (HV) que ve la punta de un aguijón: la de la superficie (Physics.hardness_profile) y, en la madera, la de la
## pared celular. La punta se embota con lo más duro que tiene que cortar.
static func micro_hv(target: Dictionary) -> float:
	if Js.truthy(target.get("skin")):
		return float(target.hv)  # la piel no tiene dureza Vickers: el catálogo da una de referencia
	var surf: float = Physics.hardness_profile(target).hvSurf
	var wall: Variant = CELL_WALL.get(target.get("id"))
	return maxf(surf, wall.hv) if wall != null else surf


## Dureza de la punta (HV): la natural (catálogo) o la del material reforjado.
static func tip_hv(claw: Dictionary, inlay: Variant = null) -> float:
	return float(inlay.hv) if is_reforged(inlay) else float(claw.hv)


# ── 4 y 5 · Anclaje, clavado y autotomía ──

## Deformación que una púa impone al agujero para pasar: ε = 2·b/(π·D), b = profundidad media de las púas.
static func barb_strain(st: Dictionary) -> float:
	var b: Variant = st.barbs.get("depthUm")
	if b == null or float(b) <= 0.0:
		return 0.0
	return 2.0 * float(b) / (PI * float(sval(st, "diameterUm")))


## Deformación que el objetivo recupera elásticamente: la piel, su deformación de rotura; un sólido dúctil, Y/E de su
## superficie (Y = H/2,8); un frágil (vidrio, cuarzo…), nada: se agrieta antes de estirarse.
static func recoverable_strain(target: Dictionary) -> float:
	if Js.truthy(target.get("skin")):
		return MODEL.skinRecoverableStrain
	if Js.truthy(target.get("brittle")):
		return 0.0
	var prof := Physics.hardness_profile(target)
	return yield_from_hv(prof.hvSurf) / (float(prof.Esurf) * 1000.0)


## ¿Se enganchan las púas en el objetivo? { barbsKnown, engaged, barbStrain, tissueStrain, anchorN }.
static func anchoring(claw: Dictionary, target: Dictionary) -> Dictionary:
	var st: Dictionary = claw.stinger
	var eps_b := barb_strain(st)
	var eps_t := recoverable_strain(target)
	var engaged := eps_b > 0.0 and eps_b < eps_t
	var serr: Variant = st.barbs.get("serrationUm")
	var anchor := 0.0
	if engaged and serr != null:
		anchor = MODEL.anchorJ * 2.0 * float(serr) / 1000.0  # dos lancetas
	return {
		"barbsKnown": st.barbs.get("depthUm") != null, "engaged": engaged, "barbStrain": eps_b, "tissueStrain": eps_t,
		"anchorN": anchor,
	}


## Riesgo de quedarse clavado según la regla de Bissessarsingh & Starr (2021) y el enfundado de Mulfinger (1992):
## "casi siempre" (púas que no se enfundan y Sr ≥ 1 u 8 púas o más), "a veces" (las enfunda), "nunca", o "" sin datos.
static func risk_from_serration(sr: Variant, barbs: Variant, sheathable: Variant) -> String:
	if sr == null or barbs == null:
		return ""
	if float(sr) >= MODEL.srStuck or int(barbs) >= MODEL.barbsStuck:
		return "a veces" if Js.truthy(sheathable) else "casi siempre"
	return "nunca"


## Riesgo documentado de la especie (tabla de autotomía): "casi siempre" (+), "a veces" (±) o "nunca" (−).
static func stuck_risk(claw: Dictionary) -> String:
	match String(claw.stinger.autotomy.get("class", "−")):
		"+":
			return "casi siempre"
		"±":
			return "a veces"
	return "nunca"


## Qué pasa al retirarse: { …anchoring, stuck, stuckRisk, autotomy, weightN, pullToWeight }. El material de un
## aguijón reforjado no cambia nada de esto: el anclaje es de la geometría y el tejido, y la autotomía, del insecto.
static func withdrawal(claw: Dictionary, target: Dictionary) -> Dictionary:
	var out := anchoring(claw, target)
	var risk := stuck_risk(claw)
	var stuck: bool = out.engaged and risk == "casi siempre"
	var weight: float = float(claw.mass) * G
	out.merge({
		"stuck": stuck, "stuckRisk": risk, "autotomy": stuck and Js.truthy(claw.stinger.autotomy.get("value")),
		"weightN": weight, "pullToWeight": out.anchorN / weight if weight > 0.0 else 0.0,
	}, true)
	return out


# ── Veneno y giro ──

## Fracción del veneno inyectada tras t segundos clavado. Bomba de válvulas (abeja): exponencial con el 90 % a t90
## (Schumacher 1994: ≥90 % en 20 s, todo en 1 min). Saco muscular (véspidos): lineal durante la picadura (estimación).
static func venom_fraction(st: Dictionary, t_s: float) -> float:
	var v: Dictionary = st.venom
	if t_s <= 0.0:
		return 0.0
	if v.get("t90S") != null:
		return 1.0 - V8.js_exp(-t_s * V8.js_log(10.0) / float(v.t90S))  # exp y log de V8: iguales en todas las plataformas
	if v.get("totalS") != null:
		return Contact.clamp_js(t_s / float(v.totalS), 0.0, 1.0)
	return 0.0


## Veneno inyectado (µg) tras t segundos, o null si no hay dato de la especie.
static func venom_delivered_ug(st: Dictionary, t_s: float) -> Variant:
	var ug: Variant = st.venom.get("ug")
	return float(ug) * venom_fraction(st, t_s) if ug != null else null


## Giro helicoidal acumulado (°) cuando la punta ha entrado depth_um de los reach_mm posibles (Wu 2014: −8,4° al
## final; el reparto lineal con la profundidad es una hipótesis para la animación). null si no está medido.
static func twist_deg(st: Dictionary, depth_um: float, reach_mm: float) -> Variant:
	var tw: Variant = sval(st, "twistDeg")
	if tw == null:
		return null
	return float(tw) * Contact.clamp_js(depth_um / (reach_mm * 1000.0), 0.0, 1.0)


# ── Ensayos ──

## El picotazo en la piel. p: { claw (aguijón), inlay, target (piel), force (N) }. Perfora si el empuje llega a F_p sin
## que el aguijón pandee antes; después las lancetas lo llevan hasta el bulbo (reach).
static func skin_sting(p: Dictionary) -> Dictionary:
	var claw: Dictionary = p.claw
	var inlay: Variant = p.get("inlay")
	var target: Dictionary = p.target
	var st: Dictionary = claw.stinger
	var stack: Array = target.tissue if Js.truthy(target.get("tissue")) else Data.SKIN_LAYERS
	var force := float(p.force)
	var f_p := puncture_force(float(claw.area), stack)
	var bk := buckling(claw, inlay)
	var buckled: bool = force >= bk.F and bk.F < f_p  # pandea antes de romper la piel
	var pierces: bool = force >= f_p and not buckled
	var reach := float(claw.reach)
	var depth_um := reach * 1000.0 if pierces else 0.0
	var layer: Variant = Physics.skin_layer_at(depth_um, stack).id if pierces else null
	var w := withdrawal(claw, target)
	var out := _static_data(claw, inlay)
	out.merge({
		"fPunctureN": f_p, "punctureRegime": puncture_regime(float(claw.area), stack), "fBuckleN": bk.F,
		"bucklingMode": bk.mode, "buckled": buckled, "pierces": pierces, "depthUm": depth_um, "layerId": layer,
		"engaged": pierces and w.engaged, "barbsKnown": w.barbsKnown, "barbStrain": w.barbStrain,
		"tissueStrain": w.tissueStrain, "anchorN": w.anchorN if pierces else 0.0,
		"pullToWeight": w.pullToWeight if pierces else 0.0, "stuck": pierces and w.stuck, "stuckRisk": w.stuckRisk,
		"autotomy": pierces and w.autotomy, "twistDeg": twist_deg(st, depth_um, reach),
		"hardnessRatio": null, "targetMicroHv": null, "tipCrushed": false, "canMark": null,
	}, true)
	return out


## Contra un sólido: la dureza a la escala de la punta y el pandeo, que limita la carga que llega a la punta.
## La profundidad la da el motor de siempre con solid_params(p).
static func solid_sting(p: Dictionary) -> Dictionary:
	var claw: Dictionary = p.claw
	var inlay: Variant = p.get("inlay")
	var target: Dictionary = p.target
	var bk := buckling(claw, inlay)
	var hv := tip_hv(claw, inlay)
	var micro := micro_hv(target)
	var ratio := hv / micro
	var crushed := ratio < Physics.MODEL.rOff
	var w := withdrawal(claw, target)
	# las púas solo pueden engancharse si la punta entra; aun así, en un sólido el aguijón sale por donde entró
	var engaged: bool = w.engaged and not crushed
	var out := _static_data(claw, inlay)
	out.merge({
		"fPunctureN": null, "punctureRegime": null, "fBuckleN": bk.F, "bucklingMode": bk.mode,
		"buckled": float(p.force) > bk.F, "pierces": null, "depthUm": null, "layerId": null,
		"engaged": engaged, "barbsKnown": w.barbsKnown, "barbStrain": w.barbStrain, "tissueStrain": w.tissueStrain,
		"anchorN": w.anchorN if engaged else 0.0, "pullToWeight": w.pullToWeight if engaged else 0.0, "stuck": false,
		"stuckRisk": w.stuckRisk, "autotomy": false, "twistDeg": null, "hardnessRatio": ratio, "targetMicroHv": micro,
		"tipCrushed": crushed, "canMark": ratio >= MODEL.markRatio,
	}, true)
	return out


## Bloque `sting` del resultado de compute() en el modelo 2.0 (la referencia de la integración). p: los parámetros de
## compute() con las entradas del catálogo (claw = el aguijón). null si la herramienta no es un aguijón.
static func sting_report(p: Dictionary) -> Variant:
	if not Insects.is_stinger(p.get("claw")):
		return null
	return skin_sting(p) if Js.truthy(p.target.get("skin")) else solid_sting(p)


## Parámetros para resolver un aguijón contra un sólido con el motor de siempre (Physics.compute con model "1.x"):
## la garra con el material de la columna (natural o reforjado), fBreak = carga de pandeo, sin incrustación y sin el
## bloque `stinger` (para no volver a entrar aquí), y el objetivo con la dureza a la escala de la punta si es celular
## (la madera de pino; la puerta ya tiene su laca encima). La cutícula no es queratina: el modo «húmeda» no la
## ablanda (wet = false). Un aguijón no golpea (½·m·v² ≈ 10⁻¹¹ J): se resuelve como empuje estático (strike = false),
## y así la carga que llega a la punta es el empuje, como en la piel. El resto de p se conserva. Ojo: resolve_tool da
## a la garra una base de 0,15 × reach; la integración debe usar el radio real del aguijón (diameterUm/2) en las chapas.
static func solid_params(p: Dictionary) -> Dictionary:
	var claw: Dictionary = p.claw
	var inlay: Variant = p.get("inlay")
	var c := claw.duplicate(true)
	c.erase("stinger")
	if is_reforged(inlay):
		c.hv = inlay.hv
		c.E = inlay.E
		c.mohs = inlay.get("mohs")
	c.fBreak = buckling(claw, inlay).F
	var t: Dictionary = p.target
	if CELL_WALL.has(t.get("id")) and not Js.truthy(t.get("layers")):
		t = t.duplicate(true)
		t.hv = CELL_WALL[t.id].hv
	var out := p.duplicate()
	out.merge({ "claw": c, "inlay": Data.INLAYS[0], "target": t, "model": "1.x", "wet": false, "strike": false }, true)
	return out


## Datos de la especie que la interfaz, la animación y el sonido necesitan (no dependen del ensayo).
static func _static_data(claw: Dictionary, inlay: Variant) -> Dictionary:
	var st: Dictionary = claw.stinger
	var reforged := is_reforged(inlay)
	return {
		"isStinger": true, "species": st.species, "reforged": reforged,
		"material": String(inlay.id) if reforged else "quitina", "tipHv": tip_hv(claw, inlay),
		"reachMm": float(claw.reach), "angleDeg": sval(st, "angleDeg"), "insertionS": sval(st, "insertionS"),
		"venomUg": st.venom.get("ug"), "pumpT90S": st.venom.get("t90S"), "pumpTotalS": st.venom.get("totalS"),
		"schmidt": sval(st, "schmidt"), "wingbeatHz": st.wingbeat.get("hz"),
	}


# ── Textos ──

## Fuerza legible en milinewtons: 0.018 · 4.3 · 86.
static func fmt_mn(f_n: float) -> String:
	var mn := f_n * 1000.0
	if mn >= 10.0:
		return Js.to_fixed(mn, 0) + " mN"
	return (Js.to_fixed(mn, 1) if mn >= 1.0 else Js.to_fixed(mn, 2)) + " mN"


## Veredicto sugerido para la piel: { verdict, vsub } (la integración puede usarlo o adaptarlo).
static func skin_verdict(r: Dictionary) -> Dictionary:
	if r.buckled:
		return {
			"verdict": "SE DOBLA EL AGUIJÓN",
			"vsub": "pandea a ~%s antes de romper la piel (hace falta ~%s)" % [fmt_mn(r.fBuckleN), fmt_mn(r.fPunctureN)],
		}
	if not r.pierces:
		return { "verdict": "NO PERFORA", "vsub": "la piel se hunde pero no se rompe (hace falta ~%s)" % fmt_mn(r.fPunctureN) }
	var mm := Js.to_fixed(float(r.depthUm) / 1000.0, 1)
	var where := "en la dermis" if r.layerId == "dermis" else ("en la grasa" if r.layerId == "grasa" else "más abajo")
	if r.autotomy:
		return {
			"verdict": "SE QUEDA CLAVADO",
			"vsub": "entra %s mm y deja el veneno %s; las púas se enganchan y la abeja se va sin su aguijón" % [mm, where],
		}
	if r.stuck:
		return { "verdict": "SE QUEDA CLAVADO", "vsub": "entra %s mm %s y las púas no lo sueltan" % [mm, where] }
	return { "verdict": "PICA Y SE VA", "vsub": "entra %s mm, deja el veneno %s y lo saca: puede repetir" % [mm, where] }
