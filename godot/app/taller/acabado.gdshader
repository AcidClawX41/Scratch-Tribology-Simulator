// Acabado superficial de la pieza del torno (unidad 9).
//
// Lee el atributo CUSTOM0 que escribe core/taller/lathe_mesh.gd por anillo (Ra en µm, tipo de pasada,
// desviación del diámetro y semiancho de la tolerancia del plano, en µm) y pinta:
// - el metal según el material: F0 medido de cada metal (uniformes que fija la escena según el kind);
// - la rugosidad a partir de Ra: bruto y desbaste mates → acabado brillante → pulido espejo;
// - las marcas de avance: crestas de perfil circular (el radio de punta rε) con el paso f del avance. Si no se da
//   f, sale de la fórmula clásica del acabado teórico en torneado, Ra ≈ f²/(32·rε), despejada: f = √(32·rε·Ra).
//   De cerca se dibujan; cuando ya no caben en un píxel se funden en rugosidad y anisotropía (lisa a lo largo de
//   la vuelta, rugosa a lo largo del eje), sin muaré;
// - las caras (hombros y refrentados), reconocidas porque su normal geométrica no coincide con la suavizada del
//   anillo: se sombrean planas y con marcas concéntricas;
// - la capa de desviación respecto al plano: ámbar donde sobra material, verde en tolerancia, rojo si se ha
//   pasado de medida y gris donde el plano no dice nada;
// - la rosca (tipo de pasada 4): el perfil es la sección axial, con un diente en V por paso en cada anillo. Con
//   thread_pitch_mm ≠ 0, cada vértice roscado se adelanta paso·θ/2π a lo largo del eje (θ, su ángulo alrededor del
//   eje): los anillos se convierten en la hélice (el paso lleva el signo del sentido de giro). Como el perfil se repite
//   cada paso, la costura de θ = ±π no se nota en la rosca completa; sí en la entrada y en la salida de rosca.
// Compatible con Forward+, Mobile y Compatibility (en Compatibility no hay anisotropía).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 metal_f0 = vec3(0.562, 0.565, 0.578);  // F0 del material mecanizado (sRGB lineal)
uniform float metallic_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec3 raw_color = vec3(0.075, 0.078, 0.085);  // superficie en bruto (calamina, extruido, estirado…)
uniform vec3 raw_patch_color = vec3(0.21, 0.15, 0.10);  // manchas del bruto (óxido sobre la calamina)
uniform float raw_metallic : hint_range(0.0, 1.0) = 0.35;
uniform float raw_roughness : hint_range(0.0, 1.0) = 0.62;
uniform float raw_lay : hint_range(0.0, 1.0) = 0.0;  // 1: líneas axiales de estirado o extrusión en el bruto
uniform float nose_radius_mm = 0.8;  // rε de la plaquita
uniform float feed_override_mm = 0.0;  // paso de las marcas (mm/vuelta) si se conoce; 0: sale de Ra
uniform int overlay = 0;  // 0 acabado · 1 desviación
uniform float thread_pitch_mm = 0.0;  // paso de la hélice con signo (0: la rosca se ve como anillos)
uniform vec3 color_ok : source_color = vec3(0.30, 0.80, 0.46);
uniform vec3 color_excess : source_color = vec3(0.98, 0.67, 0.16);
uniform vec3 color_past : source_color = vec3(0.93, 0.22, 0.22);
uniform vec3 color_noplan : source_color = vec3(0.42, 0.42, 0.46);

varying vec4 ring;  // CUSTOM0: Ra, pasada, desviación, semiancho de tolerancia
varying vec3 lpos;  // posición local (mm): x a lo largo del eje de la pieza
varying vec3 axis_view;  // eje de la pieza en el espacio de vista

void vertex() {
	ring = CUSTOM0;
	float w_thread = smoothstep(3.3, 3.7, CUSTOM0.y);
	if (thread_pitch_mm != 0.0 && w_thread > 0.0) {
		VERTEX.x += w_thread * thread_pitch_mm * atan(VERTEX.z, VERTEX.y) / 6.283185307179586;
	}
	lpos = VERTEX;
	axis_view = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Ruido de valor 3D (continuo, sin texturas)
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(17.1, 5.3, 9.7);
		a *= 0.5;
	}
	return s;
}

// Rugosidad GGX (perceptual) a partir de Ra (µm): 0,1 → 0,06 (espejo) · 0,8 → 0,18 · 3,2 → 0,33 · 12,5 → 0,53.
// Estimación visual (docs/taller/fuentes-u9.md): la pendiente de las crestas crece con f/rε, y con ella el lóbulo.
float ra_roughness(float ra) {
	float l = max(log2(max(ra, 0.05) / 0.1), 0.0);
	return clamp(0.06 + 0.02 * l + 0.0068 * l * l, 0.04, 0.85);
}

void fragment() {
	float ra = max(ring.x, 0.02);
	float pass_f = ring.y;
	float w_raw = 1.0 - smoothstep(0.3, 0.7, pass_f);
	float w_thr = smoothstep(3.3, 3.7, pass_f);  // roscado: superficie cortada, sin marcas de avance
	float w_pol = smoothstep(2.3, 2.7, pass_f) * (1.0 - w_thr);
	float w_cut = (1.0 - w_raw) * (1.0 - w_pol);
	// en los flancos de la rosca, Ra del anillo no es rugosidad (es el diente): brillo de flanco rectificado, Ra 1,6
	// (estimación visual)
	ra = mix(ra, 1.6, w_thr);

	// Caras frente a cilindros: la normal geométrica del triángulo sale de las derivadas de la posición.
	vec3 geo_n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(geo_n, VIEW) < 0.0) {
		geo_n = -geo_n;
	}
	float crease = smoothstep(0.97, 0.88, dot(geo_n, NORMAL));
	vec3 n = normalize(mix(NORMAL, geo_n, crease));

	// Marcas de avance: coordenada a través de las crestas (eje en los cilindros, radio en las caras)
	float f = feed_override_mm > 0.0 ? feed_override_mm : sqrt(32.0 * nose_radius_mm * ra * 0.001);
	f = max(f, 0.004);
	float radius = length(lpos.yz);
	float coord = mix(lpos.x, radius, crease);
	float fw = max(fwidth(coord), 1e-6);
	float vis = (1.0 - smoothstep(0.25, 0.6, fw / f)) * w_cut * (1.0 - w_thr);
	float ph = fract(coord / f) - 0.5;
	// Pendiente de la cresta circular (≈ parábola) de radio rε, algo suavizada: el flujo lateral del material y
	// el roce del filo secundario redondean las crestas reales
	float slope = 0.7 * ph * f / nose_radius_mm;
	vec3 radial_local = radius > 1e-4 ? vec3(0.0, lpos.y, lpos.z) / radius : vec3(0.0, 1.0, 0.0);
	vec3 radial_view = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(radial_local, 0.0))).xyz);
	vec3 across = normalize(mix(axis_view, radial_view, crease));
	n = normalize(n - across * slope * vis);

	// Metal mecanizado: rugosidad según Ra; de cerca las crestas se dibujan y la rugosidad residual baja.
	float rough = ra_roughness(ra);
	rough = mix(rough, rough * 0.55, vis);
	float band = vnoise(vec3(lpos.x * 2.2, 0.0, 0.0)) - 0.5;  // ninguna vuelta es idéntica a la anterior
	rough = clamp(rough + band * 0.05 * w_cut, 0.03, 0.9);
	vec3 albedo = metal_f0 * (1.0 + band * 0.06 * w_cut);
	float metal = metallic_amount;

	// Pulido con tela abrasiva: rayas circunferenciales finísimas, casi espejo
	float pol_lines = vnoise(vec3(lpos.x * 55.0, 0.0, 0.0));
	rough = mix(rough, clamp(ra_roughness(ra) * (0.75 + 0.5 * pol_lines), 0.03, 0.2), w_pol);

	// Bruto: calamina con manchas, o líneas axiales si la barra es estirada o extruida
	float patch_mask = smoothstep(0.50, 0.66, fbm(lpos * 0.12));
	float speck = vnoise(lpos * 1.7);
	float lay = vnoise(vec3(0.0, lpos.y * 5.0, lpos.z * 5.0));  // no depende de x: líneas a lo largo del eje
	vec3 rawc = mix(raw_color * (0.8 + 0.4 * speck), raw_patch_color, patch_mask * (1.0 - raw_lay));
	rawc *= mix(1.0, 0.82 + 0.36 * lay, raw_lay);
	float raw_r = clamp(raw_roughness + (speck - 0.5) * 0.15 + patch_mask * 0.12 * (1.0 - raw_lay) + (lay - 0.5) * 0.14 * raw_lay, 0.05, 1.0);
	albedo = mix(albedo, rawc, w_raw);
	metal = mix(metal, raw_metallic, w_raw);
	rough = mix(rough, raw_r, w_raw);

	vec3 emission = vec3(0.0);
	if (overlay == 1) {
		float dev = ring.z;
		float tol = ring.w;
		vec3 c = color_noplan;
		if (tol >= 0.0) {
			float soft = max(tol * 0.15, 2.0);
			float over = dev - tol;  // µm por encima de la zona: sobra material
			float under = -tol - dev;  // µm por debajo: pasado de medida
			c = mix(color_ok, color_excess, smoothstep(0.0, soft, over));
			c = mix(c, color_past, smoothstep(0.0, soft, under));
			c *= 1.0 - 0.35 * smoothstep(60.0, 1500.0, over);  // cuanto más sobra, más oscuro el ámbar
		}
		albedo = c;
		metal = 0.0;
		rough = 0.6;
		emission = c * 0.3;
	}

	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	NORMAL = n;
	EMISSION = emission;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	// Lisa a lo largo de la vuelta (tangente) y rugosa a lo largo del eje (binormal): el reflejo se estira axialmente
	ANISOTROPY = 0.6 * w_cut * (1.0 - vis) * (1.0 - crease) * (1.0 - float(overlay));
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
#endif
}
