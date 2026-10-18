## Biblioteca de materiales de las garras (unidad 5e): el material de Godot de cada material de garra (la queratina, los
## de Data.INLAYS y los de la reforja) con su acabado, para la cetrería, el coche en marcha, la galería y la reforja 3D.
##
## Los números físicos los da core/lab/claw_optics.gd (F0 de cada metal desde su índice complejo medido, el índice de
## cada canal de las gemas, su absorción por milímetro, la rugosidad de cada acabado); aquí se pasan a los parámetros de
## claw_material.gdshaderinc. Lo que es solo dibujo (cómo se ve la rugosidad, las facetas, el color del óxido) está
## marcado; el color de la queratina de cada especie, con su fuente, está en ClawOptics.KERATIN_COLORS.
##   - material(id, acabado, opts) → ShaderMaterial, de la caché: se construye UNA vez por material, acabado, calidad,
##     entorno y color, y después se reutiliza (en cada fotograma no se crea nada). Muchas garras pueden compartirlo (el
##     largo de cada una va en su malla, UV2.y); el desvanecido es del material («claw_fade»): quien desvanece sus garras
##     usa una copia (Animal3D, una por material), porque los instance uniform reservan 16 huecos por malla en un búfer
##     de 4096 en Compatibility.
##   - params(id, acabado, opts) → { parámetro: valor } y apply(mat, …): para un material propio de una garra (el de la
##     cetrería, que lleva además el calor, la sangre, las grietas y la superficie del estado).
##   - for_forge(ClawForge.result_claw(), opts, variedad, grano de pulir): el material y el acabado de una garra de la
##     reforja con una sola llamada (la capa que se ve, si la hay).
##   - surface_image(estaciones) y set_surface(mat, textura, largo): la superficie de la cetrería (contrato «La cetrería en
##     alta definición y la superficie de la garra»: R = log₁₀(Ra/0,01 µm)/log₁₀(5000), G = quemado, B = desconchón,
##     A = rayado/180°), que el material lee por estación a lo largo de la garra.
##   - opts: quality («escritorio» | «movil»: el teléfono usa el sombreador opaco, sin leer la pantalla, con un solo rayo
##     por canal), env («taller» | «carretera»: el entorno que se ve dentro de las gemas), color (la queratina natural de
##     la especie), apex_mm (dónde está la punta, si la malla no lo dice en UV2.y), facet_mm (el largo de cada faceta; por
##     defecto, un 20 % del de la garra), seed (variación de las facetas y las rayas), uv_mode (0, las mallas de garra; 1,
##     otra malla), thick_mm (espesor con uv_mode 1).
## Funciona igual en Forward+, Mobile y Compatibility (comprobado en Compatibility con las capturas).
extends RefCounted

const ClawOptics = preload("res://core/lab/claw_optics.gd")
const SOLID = preload("res://app/common/claw_solid.gdshader")
const GEM = preload("res://app/common/claw_gem.gdshader")

## Tipo de sombreado de cada familia de claw_optics.gd (4, desde la 5p: el polímero de cuerpo translúcido, el acrílico
## dental y la resina).
const KIND := { "queratina": 0, "metal": 1, "mineral": 1, "gema": 2, "vidrio": 2, "ceramica": 3, "polimero": 4 }
## Facetas alrededor de una garra tallada (dibujo: una talla a mano, de bisel en bisel); el largo de cada una, por defecto
## un 20 % del de la garra (claw_facet_len en el sombreador), o opts.facet_mm.
const FACETS := 10.0
## Barniz de la queratina pulida por el uso (dibujo, petición 36: el brillo nítido de la captura de referencia).
const KERATIN_CLEARCOAT := 0.3
const KERATIN_CLEARCOAT_ROUGH := 0.06
## Rugosidad de la queratina natural (dibujo: lisa y brillante, pulida por el uso, como en la vista «La garra» de la
## Beta 2, la referencia de la petición 36).
const KERATIN_ROUGH := 0.17
## Color de la queratina carbonizada (dibujo).
const CHAR_COLOR := Color("#1a120d")
## Color del óxido o del grabado del fuego de cada material (dibujo, con lo que dice la reforja: la cascarilla del acero,
## el óxido amarillo del carburo de tungsteno, la capa gris del titanio y el diamante grabado y quemado).
const OXIDE_COLOR := {
	"acero": Color("#2f2c2b"), "titanio": Color("#6d6a66"), "tungsteno": Color("#b9a24c"), "oro": Color("#c9a24a"),
	"diamante": Color("#cfd3d6"), "cromo": Color("#55575a"), "tin": Color("#8a7340"), "hematites": Color("#5a2a20"),
}
## La superficie de la cetrería: Ra mínima y máxima de la textura (µm). R va en escala logarítmica entre las dos, para que
## en 8 bits se distingan los pulidos finos (de 0,01 a 50 µm, pasos de un 3,4 %): con R = Ra/50 todo lo que bajaba de
## 0,2 µm se leía como un espejo.
const SURFACE_RA_MIN := 0.01
const SURFACE_RA_MAX := 50.0

static var _cache := {}
## Materiales construidos desde que se cargó la biblioteca (lo vigilan los tests: una vez por clave).
static var built := 0


## Rugosidad de Godot de una rugosidad rms σ (µm). Dibujo: de espejo (5 nm) a mate (micras), en escala logarítmica; la
## misma cuenta que claw_roughness_of en el sombreador.
static func roughness_of(sigma_um: float) -> float:
	var nm := maxf(sigma_um * 1000.0, 0.0)
	return clampf(0.03 + 0.2 * (log(maxf(nm / 5.0, 1.0)) / log(10.0)), 0.03, 0.75)


## Lo lechoso de una gema o un vidrio esmerilados (0-1): la luz que la superficie rota difunde. Dibujo, con σ.
static func frost_of(sigma_um: float) -> float:
	return smoothstep(0.08, 0.9, sigma_um)


## Clave de un acabado (lo que cambia el material).
static func finish_key(f: Dictionary) -> String:
	return "%s|%.4f|%s|%.2f|%d|%d|%.2f|%.2f|%.2f" % [String(f.get("id", "")), float(f.get("sigma_um", 0.0)), str(bool(f.get("facets", false))),
		float(f.get("scratch", 0.0)), int(f.get("chips", 0)), int(f.get("cracks", 0)), float(f.get("oxide", 0.0)), float(f.get("burn", 0.0)),
		float(f.get("pores", 0.0))]


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Vector3.ZERO


## Los parámetros del sombreador de un material con su acabado. id: el de claw_optics.gd («none» la queratina);
## finish: el de ClawOptics.finish…() ({} = el de por defecto del material).
static func params(id: String, finish: Dictionary = {}, opts := {}) -> Dictionary:
	var mid := id if ClawOptics.MATERIALS.has(id) else "none"
	var lk := ClawOptics.look(mid)
	var f := finish if not finish.is_empty() else ClawOptics.default_finish(mid)
	var fam := String(lk.family)
	var kind := int(KIND.get(fam, 0))
	var mobile := String(opts.get("quality", "")) == "movil"
	var f0 := _v3(lk.f0)
	var ior := _v3(lk.ior) if not (lk.ior as Array).is_empty() else Vector3.ONE * 1.5
	var ior_e := _v3(lk.ior_e) if not (lk.ior_e as Array).is_empty() else ior
	var sigma := float(f.get("sigma_um", 0.005))
	var apex := float(opts.get("apex_mm", 30.0))
	var p := {
		"claw_kind": kind, "claw_f0": f0, "claw_ior": ior, "claw_ior_e": ior_e,
		"claw_absorb": _v3(lk.absorption), "claw_tint": _v3(lk.tint),
		"claw_rough": roughness_of(sigma), "claw_frost": frost_of(sigma) if kind in [2, 3, 4] else 0.0,
		"claw_scatter": float(lk.get("scatter", 0.0)),
		"claw_facets": FACETS if bool(f.get("facets", false)) and kind != 0 else 0.0,
		"claw_facet_mm": float(opts.get("facet_mm", -1.0)),
		"claw_scratch": float(f.get("scratch", 0.0)), "claw_scratch_deg": float(opts.get("scratch_deg", 0.0)), "claw_chips": float(f.get("chips", 0)),
		"claw_cracks": float(f.get("cracks", 0)), "claw_oxide": float(f.get("oxide", 0.0)), "claw_burn": float(f.get("burn", 0.0)),
		"claw_pores": float(f.get("pores", 0.0)), "claw_clear": 1.0 if bool(opts.get("clear", false)) else 0.0,
		"claw_oxide_color": OXIDE_COLOR.get(mid, Color("#3a3634")), "claw_char_color": CHAR_COLOR, "claw_growth": 0.0, "claw_clearcoat": 0.0,
		"claw_clearcoat_rough": KERATIN_CLEARCOAT_ROUGH,
		"claw_env": 1.0 if String(opts.get("env", "taller")) == "carretera" else 0.0, "claw_env_energy": float(opts.get("env_energy", 1.0)),
		"claw_apex_mm": apex, "claw_thick_mm": float(opts.get("thick_mm", 4.0)),
		"claw_seed": float(opts.get("seed", 0.0)), "claw_uv_mode": int(opts.get("uv_mode", 0)), "claw_quality": 1 if mobile else 0,
	}
	# el reflejo de los dieléctricos: SPECULAR de Godot es F0 = 0,16·s² (recortado a 1: el diamante, 0,172 → 0,16)
	var f0m := (f0.x + f0.y + f0.z) / 3.0
	p["claw_spec"] = clampf(sqrt(f0m / 0.16), 0.0, 1.0) if kind != 1 else 0.5
	match kind:
		0:
			var col: Color = opts.get("color", Color("#2e2a26"))
			p["claw_base"] = col
			p["claw_rough"] = KERATIN_ROUGH if finish.is_empty() else maxf(roughness_of(sigma), KERATIN_ROUGH * 0.6)
			p["claw_growth"] = 1.0
			p["claw_clearcoat"] = KERATIN_CLEARCOAT
		3, 4:
			# la cerámica y el polímero: el color de su cuerpo (sRGB lineal en claw_optics.gd)
			var alb := _v3(lk.albedo)
			p["claw_base"] = Color(alb.x, alb.y, alb.z).linear_to_srgb()
		_:
			p["claw_base"] = Color(0.5, 0.5, 0.5)
	return p


## Pone los parámetros en un material (los que no son del modelo, el calor o la sangre de la cetrería, no se tocan).
static func apply(mat: ShaderMaterial, id: String, finish: Dictionary = {}, opts := {}) -> void:
	var p := params(id, finish, opts)
	for k: String in p:
		mat.set_shader_parameter(k, p[k])


## El sombreador de un material: las gemas y los vidrios del escritorio leen la pantalla (se ve a través).
static func shader_for(id: String, opts := {}) -> Shader:
	var lk := ClawOptics.look(id if ClawOptics.MATERIALS.has(id) else "none")
	if bool(lk.get("transparent", false)) and String(opts.get("quality", "")) != "movil":
		return GEM
	return SOLID


## Clave de la caché.
static func key_of(id: String, finish: Dictionary, opts: Dictionary) -> String:
	var col: Color = opts.get("color", Color("#2e2a26"))
	var surf: Dictionary = opts.get("surface", {})
	return "%s|%s|%s|%s|%s|%.1f|%.2f|%.2f|%d|%.1f|%s|%.0f|%s" % [id, finish_key(finish), String(opts.get("quality", "escritorio")),
		String(opts.get("env", "taller")), col.to_html(false), float(opts.get("apex_mm", 30.0)), float(opts.get("facet_mm", -1.0)),
		float(opts.get("seed", 0.0)), int(opts.get("uv_mode", 0)), float(opts.get("thick_mm", 4.0)), str(bool(opts.get("clear", false))),
		float(opts.get("scratch_deg", 0.0)), String(surf.get("id", ""))]


## El material de un material de garra con su acabado: de la caché, o se construye una sola vez. Con opts.surface
## ({ id, tex, length_mm }), el material lee esa superficie (la de la cetrería, o una de muestra en la galería).
static func material(id: String, finish: Dictionary = {}, opts := {}) -> ShaderMaterial:
	var mid := id if ClawOptics.MATERIALS.has(id) else "none"
	var f := finish if not finish.is_empty() else ClawOptics.default_finish(mid)
	var key := key_of(mid, f, opts)
	var m: ShaderMaterial = _cache.get(key)
	if m != null:
		return m
	m = ShaderMaterial.new()
	m.shader = shader_for(mid, opts)
	apply(m, mid, f, opts)
	var surf: Dictionary = opts.get("surface", {})
	if surf.get("tex") is Texture2D:
		set_surface(m, surf.tex as Texture2D, float(surf.get("length_mm", 30.0)))
	_cache[key] = m
	built += 1
	return m


## El material de una garra que sale de la reforja (ClawForge.result_claw()), con la capa que se ve si la hay.
static func for_forge(result_claw: Dictionary, opts := {}, variety := "", polish_grain_um: Variant = null) -> ShaderMaterial:
	var s := ClawOptics.forge_surface(result_claw, variety, polish_grain_um)
	var o := opts.duplicate()
	var coat: Variant = s.get("coat")
	if coat is Dictionary and bool((coat as Dictionary).get("clear", false)):
		o["clear"] = true
	return material(String(s.material), s.finish, o)


## Materiales en la caché.
static func cache_size() -> int:
	return _cache.size()


## Vacía la caché (tests).
static func clear_cache() -> void:
	_cache.clear()


# ════════ La superficie de la cetrería ════════

## R de la textura de la superficie para una Ra (µm): log₁₀(Ra/0,01)/log₁₀(5000), recortado a [0, 1].
static func surface_r(ra_um: float) -> float:
	var ra := clampf(ra_um, SURFACE_RA_MIN, SURFACE_RA_MAX)
	return clampf(log(ra / SURFACE_RA_MIN) / log(SURFACE_RA_MAX / SURFACE_RA_MIN), 0.0, 1.0)


## Ra (µm) de un R de la textura: la inversa de surface_r (la misma cuenta que hace el sombreador).
static func surface_ra(r: float) -> float:
	return SURFACE_RA_MIN * pow(SURFACE_RA_MAX / SURFACE_RA_MIN, clampf(r, 0.0, 1.0))


## La imagen de la superficie (una columna por estación, RGBA8): stations = [{ ra_um, burn, chip, scratch_deg }] a lo
## largo de la garra, de la base a la punta. R = surface_r(Ra), G = quemado, B = desconchón, A = rayado/180°.
static func surface_image(stations: Array) -> Image:
	var n := maxi(stations.size(), 1)
	var img := Image.create_empty(n, 1, false, Image.FORMAT_RGBA8)
	for i in stations.size():
		var e: Dictionary = stations[i]
		img.set_pixel(i, 0, Color(surface_r(float(e.get("ra_um", 0.0))), clampf(float(e.get("burn", 0.0)), 0.0, 1.0),
			clampf(float(e.get("chip", 0.0)), 0.0, 1.0), clampf(fposmod(float(e.get("scratch_deg", 0.0)), 180.0) / 180.0, 0.0, 1.0)))
	return img


## Pone la superficie en un material (tex: la de surface_image; length_mm: el largo de la garra, el de surface_range).
static func set_surface(mat: ShaderMaterial, tex: Texture2D, length_mm: float) -> void:
	mat.set_shader_parameter("surface_tex", tex)
	mat.set_shader_parameter("surface_range", Vector2(0.0, length_mm))


## Quita la superficie (vuelve a la del acabado).
static func clear_surface(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("surface_range", Vector2.ZERO)


# ════════ Luz del sol (unidad 4w) ════════

## El cielo de la carretera que reflejan y refractan las garras con el entorno «carretera» (claw_env_road del sombreador):
## por defecto, el atardecer de siempre (los mismos números que tenía escritos el sombreador); con un sol del coche
## (CarScene.set_light), su dirección, su color, su brillo y los colores de su cielo. Dibujo. Lo ponen en sus copias quienes
## pintan garras en la carretera (Animal3D, HD3D: apply_road_light).
const ROAD_DEFAULTS := {
	"claw_road_sun_dir": Vector3(0.42, 0.8, 0.45), "claw_road_sun_color": Vector3(1.0, 0.86, 0.66), "claw_road_sun_k": 30.0,
	"claw_road_zenith": Vector3(0.15, 0.14, 0.24), "claw_road_mid": Vector3(0.27, 0.26, 0.31), "claw_road_horizon": Vector3(0.92, 0.80, 0.70),
	"claw_road_ground_near": Vector3(0.19, 0.17, 0.19), "claw_road_ground": Vector3(0.07, 0.06, 0.08), "claw_road_neutral": 0.0, "claw_road_gem_sun": 0.0,
}
static var road_light := {}


## La luz de la carretera de ahora ({} = la de siempre); solo los parámetros de ROAD_DEFAULTS.
static func set_road_light(p: Dictionary) -> void:
	road_light = {}
	for k: String in p:
		if ROAD_DEFAULTS.has(k):
			road_light[k] = p[k]


## Pone la luz de la carretera de ahora en un material de garra (una copia con el entorno «carretera»).
static func apply_road_light(mat: ShaderMaterial) -> void:
	for k: String in ROAD_DEFAULTS:
		mat.set_shader_parameter(k, road_light.get(k, ROAD_DEFAULTS[k]))
