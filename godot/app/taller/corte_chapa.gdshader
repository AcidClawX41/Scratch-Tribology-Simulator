// Chapa de coche pintada, cortada con una radial (escena educativa del Taller industrial).
//
// Capas desde fuera (packages/core/src/data.js → PAINT_LAYERS): barniz 0-45 µm, color 45-60, imprimación 60-85 y
// anticorrosivo 85-110 sobre el metal, y la cataforesis por dentro. Alrededor del surco dibuja:
//  · la pintura quemada a cada lado (paint_burn_mm): amarillea, se tuesta, se carboniza y, junto al borde, se va;
//  · los colores de revenido del acero según la temperatura que alcanzó cada punto (TM 9-237, tabla IV: paja
//    ~227 °C, azul ~299 °C). El perfil es T(d) = 20 + (T0 − 20)·e^(−d/λ), con λ tal que a d = haz_mm la chapa
//    llegó a ~200 °C (donde empieza el primer color): es la lectura que hace la escena de haz_mm y temp_c;
//  · la incandescencia del frente del corte (rampa de la tabla V del TM 9-237);
//  · la rebaba, las paredes del surco con las marcas del disco y los hilos de plástico fundido.
// Lo que se dibuja lo dice el atributo UV2.y (tipo de cara, ver radial3d/panel_builder.gd); UV = (u, v) en mm.
// Compatible con Forward+, Mobile y Compatibility: sin CLEARCOAT, sin texturas de pantalla ni arrays de uniformes.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ── Geometría del corte (mm, en el espacio (u, v) de la chapa) ──
uniform float front_top_mm = 0.0;     // hasta dónde llega el surco en la cara pintada
uniform float front_bottom_mm = 0.0;  // y en la cara interior (el disco es redondo: llega algo menos)
uniform float kerf_mm = 1.15;
uniform float tilt_tan = 0.0;          // tan(ángulo del disco): el surco se ladea con la profundidad
uniform float total_mm = 1.035;        // pintura + chapa + cataforesis interior
uniform vec4 layers_mm = vec4(0.045, 0.060, 0.085, 0.110);  // fondo de barniz, color, imprimación y anticorrosivo
uniform float metal_mm = 0.9;

// ── Aspecto (colores del laboratorio) ──
uniform vec3 paint_color : source_color = vec3(0.184, 0.420, 0.341);
uniform vec3 paint_lo : source_color = vec3(0.086, 0.231, 0.188);
uniform vec3 flake_color : source_color = vec3(1.0);
uniform float flake = 0.0;
uniform vec3 clear_color : source_color = vec3(0.886, 0.953, 0.973);
uniform vec3 primer_color : source_color = vec3(0.714, 0.733, 0.753);
uniform vec3 ecoat_color : source_color = vec3(0.361, 0.408, 0.329);
uniform vec3 metal_color : source_color = vec3(0.706, 0.733, 0.765);
uniform vec3 metal_lo : source_color = vec3(0.478, 0.514, 0.553);
uniform float is_plastic = 0.0;    // 1: la carrocería es plástico
uniform float inner_ecoat = 1.0;   // 1: la cara interior lleva cataforesis

// ── Calor (salida del modelo de corte) ──
uniform float burn_mm = 1.8;
uniform float haz_mm = 1.6;
uniform float temp_c = 250.0;
uniform int tint_mode = 0;          // 0 acero (revenido) · 1 aluminio (gris mate) · 2 plástico (fundido)
uniform vec3 tint_color : source_color = vec3(0.64, 0.67, 0.69);
uniform sampler2D temper_ramp : source_color, filter_linear, repeat_disable;
uniform float temper_min_c = 150.0;
uniform float temper_max_c = 450.0;
uniform sampler2D heat_ramp : source_color, filter_linear, repeat_disable;  // incandescencia de 300 a 1300 °C
uniform float glow_c = 0.0;          // temperatura del frente del corte (0: no brilla)
uniform float deformation_mm = 0.0;  // alabeo de la chapa junto al corte
uniform float section_emission = 0.12;  // la sección se ve clara aunque la luz venga de lado

varying vec2 v_uv;
varying float v_depth;
varying float v_face;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

vec4 temper(float t) {
	float k = clamp((t - temper_min_c) / (temper_max_c - temper_min_c), 0.0, 1.0);
	return texture(temper_ramp, vec2(k, 0.5));
}

vec3 incandescence(float t) {
	float k = clamp((t - 300.0) / 1000.0, 0.0, 1.0);
	return texture(heat_ramp, vec2(k, 0.5)).rgb;
}

// Temperatura máxima alcanzada a d mm del borde del surco.
float temp_at(float d) {
	float lam = haz_mm;
	if (temp_c > 205.0) {
		lam = haz_mm / max(log((temp_c - 20.0) / 180.0), 0.05);
	}
	return 20.0 + (temp_c - 20.0) * exp(-d / max(lam, 0.05));
}

// Metal (o núcleo de plástico) con el color que le deja el calor a esa temperatura.
vec3 heated_core(vec3 base, float t, float n) {
	if (tint_mode == 0) {
		vec4 tc = temper(t);
		return mix(base, tc.rgb * (0.85 + 0.3 * n), tc.a);
	} else if (tint_mode == 1) {
		float k = clamp((t - 60.0) / 200.0, 0.0, 0.75);
		return mix(base, tint_color * (0.8 + 0.3 * n), k);
	}
	float k = clamp((t - 120.0) / 130.0, 0.0, 1.0);
	return mix(base, tint_color * (0.9 + 0.2 * n), k);
}

void vertex() {
	v_uv = UV;
	v_depth = UV2.x;
	v_face = UV2.y;
	// Alabeo por el calor: solo lo ya cortado, junto al surco, con una ondulación suave.
	float behind = clamp((front_top_mm - UV.x) / 20.0, 0.0, 1.0);
	float warp = deformation_mm * 0.001 * behind * exp(-abs(UV.y) / 14.0) * (0.55 + 0.45 * sin(UV.x * 0.09));
	VERTEX.y += warp;
}

void fragment() {
	float face = v_face;
	float depth = v_depth;
	vec2 uv = v_uv;
	float half_w = 0.5 * kerf_mm * sqrt(1.0 + tilt_tan * tilt_tan);
	float fd = clamp(depth / max(total_mm, 1e-4), 0.0, 1.0);
	float front = mix(front_top_mm, front_bottom_mm, fd);
	float dv = abs(uv.y - tilt_tan * depth) - half_w;  // < 0 dentro del surco
	float du = uv.x - front;                            // > 0 por delante del corte
	bool started = front > 0.0;

	// El surco: se abre en las caras y en el canto; las paredes, rebabas e hilos solo existen detrás del frente.
	if (face < 2.5) {
		if (started && du < 0.0 && dv < 0.0) {
			discard;
		}
	} else if (!started || du > 0.05) {
		discard;
	}

	float dist = started ? length(vec2(max(du, 0.0), max(dv, 0.0))) : 1e4;
	float n1 = vnoise(uv * 2.2);
	float n2 = vnoise(uv * 14.0 + vec2(depth * 7.0));
	float t_here = temp_at(dist);
	float s = dist / max(burn_mm, 0.01);  // 0 en el borde del surco, 1 donde acaba la pintura quemada

	vec3 core = mix(metal_lo, metal_color, 0.55 + 0.45 * n1);
	vec3 albedo;
	float rough;
	float metallic;
	float spec = 0.5;
	vec3 emit = vec3(0.0);

	if (face < 0.5 || (face > 0.5 && face < 1.5)) {
		// ── Caras: pintada (0) o interior (1) ──
		bool outer = face < 0.5;
		vec3 coat;
		if (outer) {
			coat = mix(paint_lo, paint_color, 0.7 + 0.3 * n1);
			// escamas del metalizado: pocas y pequeñas
			float sparkle = step(0.9975, hash21(floor(uv * 7.0)));
			coat = mix(coat, flake_color, sparkle * flake * 0.35);
			rough = 0.3;
			spec = 0.35;
		} else if (inner_ecoat > 0.5) {
			coat = ecoat_color * (0.9 + 0.2 * n1);
			rough = 0.55;
		} else {
			coat = core;
			rough = 0.45;
		}
		metallic = 0.0;
		albedo = coat;
		if (s < 1.0) {
			// Pintura quemada: amarillea, se tuesta y se carboniza; junto al borde se ha ido y deja ver el metal.
			float blister = step(0.7, vnoise(uv * 5.0 + 3.0)) * 0.25;
			vec3 yellowed = mix(coat, vec3(0.78, 0.63, 0.36), 0.45);
			vec3 toasted = vec3(0.34, 0.21, 0.11) * (0.8 + 0.4 * n2);
			vec3 charred = vec3(0.045, 0.038, 0.034) * (0.8 + 0.6 * n2);
			albedo = mix(coat, yellowed, smoothstep(1.0, 0.75, s));
			albedo = mix(albedo, toasted, smoothstep(0.8, 0.5, s));
			albedo = mix(albedo, charred, smoothstep(0.55, 0.3, s + blister * 0.3));
			rough = mix(rough, 0.9, smoothstep(0.9, 0.5, s));
			float bare = smoothstep(0.24, 0.16, s + (n2 - 0.5) * 0.06);
			vec3 bare_col = heated_core(core, t_here, n2);
			albedo = mix(albedo, bare_col, bare);
			metallic = mix(metallic, is_plastic > 0.5 ? 0.0 : 0.75, bare);
			rough = mix(rough, is_plastic > 0.5 ? 0.25 : 0.38, bare);
		}
	} else if (face < 3.5) {
		// ── Canto (2) y paredes del surco (3): la sección de las capas ──
		bool wall = face > 2.5;
		float dh = wall ? 0.0 : max(dv, 0.0);  // distancia horizontal al borde del surco
		float th = temp_at(dh);
		float char_k = smoothstep(burn_mm, burn_mm * 0.15, dh);
		vec3 layer;
		float lm = 0.0;
		if (depth < layers_mm.x) {
			layer = mix(paint_color, clear_color, 0.6);
		} else if (depth < layers_mm.y) {
			layer = paint_color;
		} else if (depth < layers_mm.z) {
			layer = primer_color;
		} else if (depth < layers_mm.w) {
			layer = ecoat_color;
		} else if (depth < layers_mm.w + metal_mm) {
			layer = heated_core(core, th, n2);
			lm = 1.0;
		} else {
			layer = inner_ecoat > 0.5 ? ecoat_color : core;
		}
		if (lm < 0.5) {
			layer = mix(layer, vec3(0.05, 0.04, 0.035), char_k * 0.9);
		}
		if (wall && lm > 0.5) {
			// Marcas del disco en la pared cortada: arcos finos casi paralelos a la cara.
			float marks = 0.5 + 0.5 * sin(uv.x * 9.0 + depth * 30.0 + n2 * 3.0);
			layer *= 0.82 + 0.3 * marks;
		}
		albedo = layer;
		// la cara cortada es rugosa (amolada o cizallada): poco espejo
		metallic = lm * (is_plastic > 0.5 ? 0.0 : (wall ? 0.6 : 0.3));
		rough = lm > 0.5 ? (wall ? 0.45 : 0.7) : 0.6;
		if (!wall) {
			emit += albedo * section_emission;
		}
	} else if (face < 4.5) {
		// ── Rebaba: metal que se dobló al rojo y se oxidó (o plástico fundido que se volvió a solidificar) ──
		albedo = heated_core(core, temp_c + 60.0, n2) * 0.8;
		if (is_plastic > 0.5) {
			albedo = mix(core, tint_color, 0.7) * (0.9 + 0.2 * n2);
		}
		metallic = is_plastic > 0.5 ? 0.0 : 0.55;
		rough = is_plastic > 0.5 ? 0.2 : 0.5;
		emit += albedo * section_emission * 0.6;
	} else {
		// ── Hilos de plástico fundido ──
		albedo = mix(core, tint_color, 0.5) * (0.85 + 0.3 * n2);
		metallic = 0.0;
		rough = 0.18;
		spec = 0.7;
	}

	// Incandescencia del frente del corte (solo los metales que brillan: el acero).
	if (glow_c > 0.0 && started) {
		float behind_front = max(front - uv.x, 0.0);
		float g = glow_c * exp(-behind_front / 1.6) * exp(-max(dv, 0.0) / 0.35) * step(uv.x, front + 0.2);
		if (face > 1.5 && face < 4.5) {
			g = glow_c * exp(-behind_front / 1.6) * exp(-(face < 2.5 ? max(dv, 0.0) : 0.0) / 0.35);
		}
		emit += incandescence(g) * 2.2 * smoothstep(420.0, 700.0, g);
	}

	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
