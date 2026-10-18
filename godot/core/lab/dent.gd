## Tribología biológica · abolladura de la chapa (modelo 2.0, unidad 1f).
##
## La energía de un golpe que no perfora (un zarpazo de oso contra la puerta de acero) o un empuje fuerte abollan la
## chapa. Especificación y fuentes: docs/fisica/pulido-materiales.md (tema 5).
##   - Mecanismo rígido-plástico de una placa con una carga concentrada (análisis límite; Jones 1989): la chapa no se
##     abolla hasta la carga de colapso 2π·M0 = π·σ·t²/2 (M0 = σ·t²/4), sea cual sea el tamaño del panel; después,
##     el hoyuelo cónico de profundidad δ añade el trabajo de membrana σ·t·ΔA, con ΔA = π·δ²/2. Trabajo y fuerza:
##         W(δ) = (π·σ·t/2)·δ·(t + δ)        F(δ) = dW/dδ = (π·σ·t/2)·(t + 2δ)
##   - σ es la tensión de flujo de la chapa conformada por un factor de calibración C = 0,766, ajustado a la
##     abolladura medida por Nippon Steel (2013, fig. 6): acero BH de 0,7 mm con 270 MPa tras el 2 % de estirado y el
##     horneado, bola de 25 mm, 200 N → 0,09 mm. Con ese mismo C salen los otros tres aceros de la figura (270D,
##     340H, 440P) con un error del 15-30 %.
##   - En un golpe, la fuerza de pico sale como en la ventana (apartado 15): la masa contra el muelle blando de la
##     pata (limbStiffness de physics.gd, que se recibe como dato). La energía se reparte entre la abolladura y ese
##     muelle: W_panel(δ(F)) + F²/(2k) = E.
## No se aplica al plástico (el termoplástico recupera) ni cuando la chapa queda perforada.
## Unidades: N · mm · MPa · mJ (= N·mm; las salidas en J). Funciones puras, deterministas y seguras para hilos.
## Uso: const Dent = preload("res://core/lab/dent.gd").
extends RefCounted

## Factor de calibración de la tensión de flujo (Nippon Steel 2013, fig. 6; ver arriba).
const DENT_C := 0.766
## Abolladura que ya se ve en un panel brillante (mm): el criterio de resistencia a la abolladura de la industria, «la
## carga que deja una abolladura de 0,1 mm» (US 7 158 922 B2), y el orden de las que mide Nippon Steel (0,05-0,2 mm) para
## comparar aceros.
const VISIBLE_MM := 0.1


## Rigidez plástica del mecanismo (N/mm): π·C·σ·t/2.
static func plastic_k(sigma_mpa: float, t_mm: float) -> float:
	return PI * DENT_C * sigma_mpa * t_mm / 2.0


## Carga de colapso (N): la que empieza a abollar, π·C·σ·t²/2 (= 2π·M0).
static func collapse_load(sigma_mpa: float, t_mm: float) -> float:
	return plastic_k(sigma_mpa, t_mm) * t_mm


## Fuerza (N) que mantiene una abolladura de profundidad δ (mm).
static func load_at(sigma_mpa: float, t_mm: float, delta_mm: float) -> float:
	return plastic_k(sigma_mpa, t_mm) * (t_mm + 2.0 * maxf(delta_mm, 0.0))


## Trabajo plástico (mJ) de una abolladura de profundidad δ (mm).
static func energy_mj(sigma_mpa: float, t_mm: float, delta_mm: float) -> float:
	var d := maxf(delta_mm, 0.0)
	return plastic_k(sigma_mpa, t_mm) * d * (t_mm + d)


## Profundidad (mm) de la abolladura con una fuerza F (N): 0 por debajo del colapso.
static func depth_for_load(sigma_mpa: float, t_mm: float, f_n: float) -> float:
	return maxf(0.0, (f_n / plastic_k(sigma_mpa, t_mm) - t_mm) / 2.0)


## Profundidad (mm) que absorbe una energía W (mJ): la raíz positiva de δ² + t·δ − W/k = 0.
static func depth_for_energy(sigma_mpa: float, t_mm: float, w_mj: float) -> float:
	if w_mj <= 0.0:
		return 0.0
	var k := plastic_k(sigma_mpa, t_mm)
	return (-t_mm + sqrt(t_mm * t_mm + 4.0 * w_mj / k)) / 2.0


## Chapa de un material (la carrocería metálica de un coche o la puerta de aluminio): { t (mm), sigma (MPa) } con la
## σ0 del motor como tensión de flujo. null si no es una chapa metálica.
static func panel_of(target: Dictionary) -> Variant:
	var body: Variant = target.get("body")
	if body != null:
		if body.get("metal", false) != true:
			return null
		return { "t": body.t / 1000.0, "sigma": body.sigma0 }
	if target.get("sigma0") != null and target.get("thickness") != null:
		return { "t": target.thickness, "sigma": target.sigma0 }
	return null


## Abolladura por un golpe: energía energy_mj (mJ, la que no se ha quedado ya la punta), muelle de la pata k_limb
## (N/mm) y, si la herramienta se rompe antes, la fuerza máxima que transmite f_cap (N, INF si no hay límite).
## { depthMm, peakN, panelJ, limbJ, collapseN }.
static func strike(sigma_mpa: float, t_mm: float, energy_mj_in: float, k_limb: float, f_cap: float = INF) -> Dictionary:
	var fc := collapse_load(sigma_mpa, t_mm)
	var e := maxf(energy_mj_in, 0.0)
	var f_free := minf(sqrt(2.0 * k_limb * e), f_cap)  # pico si la chapa no cediera
	if f_free <= fc:
		return { "depthMm": 0.0, "peakN": f_free, "panelJ": 0.0, "limbJ": f_free * f_free / (2.0 * k_limb) / 1000.0, "collapseN": fc }
	# W_panel(δ(F)) + F²/(2k) crece con F: bisección entre el colapso y el pico sin abolladura
	var lo := fc
	var hi := f_free
	for i in 80:
		var mid := (lo + hi) / 2.0
		var w := energy_mj(sigma_mpa, t_mm, depth_for_load(sigma_mpa, t_mm, mid)) + mid * mid / (2.0 * k_limb)
		if w >= e:
			hi = mid
		else:
			lo = mid
	# si la herramienta limita la fuerza (f_cap) y aún sobra energía, la chapa no pasa de δ(f_cap)
	var peak := hi
	var d := depth_for_load(sigma_mpa, t_mm, peak)
	return {
		"depthMm": d, "peakN": peak, "panelJ": energy_mj(sigma_mpa, t_mm, d) / 1000.0,
		"limbJ": peak * peak / (2.0 * k_limb) / 1000.0, "collapseN": fc,
	}


## Resultado para compute() (modelo 2.0). En un golpe (strike), energy_j es la energía que sobra tras la punta
## (energyJ − workJ) y k_limb el muelle de la pata; empujando o rayando, force_n es la carga normal. null si no es
## una chapa metálica o si queda perforada (through).
## { depthMm, peakN, panelJ, collapseN, visible }.
static func evaluate(
	target: Dictionary, force_n: float, is_strike: bool, energy_j: float, k_limb: float, through: bool,
	f_cap: float = INF
) -> Variant:
	var panel: Variant = panel_of(target)
	if panel == null or through:
		return null
	var out: Dictionary
	if is_strike:
		out = strike(panel.sigma, panel.t, energy_j * 1000.0, k_limb, f_cap)
	else:
		var f := minf(force_n, f_cap)
		var d := depth_for_load(panel.sigma, panel.t, f)
		out = {
			"depthMm": d, "peakN": f, "panelJ": energy_mj(panel.sigma, panel.t, d) / 1000.0, "limbJ": 0.0,
			"collapseN": collapse_load(panel.sigma, panel.t),
		}
	out["visible"] = out.depthMm >= VISIBLE_MM
	return out
