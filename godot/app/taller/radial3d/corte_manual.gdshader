// Chapa de coche pintada, cortada A MANO con la radial (modo manual del Taller industrial).
//
// Dibuja lo mismo que corte_chapa.gdshader (capas de la pintura, pintura quemada, colores de revenido, incandescencia
// del frente, rebaba, paredes con las marcas del disco e hilos de plástico), pero el surco no va de u = 0 a un frente:
// lo dice, en cada punto u de la línea de corte, el mapa del surco que escribe core/taller/radial_manual.gd, subido
// como textura de datos (2 filas × n muestras, RGBA en float, una muestra cada 0,25 mm):
//   fila 0: profundidad cortada (mm) · semiancho del surco en la cara pintada (mm) · tan(inclinación) · rebaba lado −
//   fila 1: rebaba lado + (mm) · pintura quemada (mm desde el borde del surco) · zona > 200 °C (mm) · fundido (0-1)
// Las paredes, el fondo del surco, las rebabas y los hilos son mallas de toda la línea, hechas en la línea central una
// sola vez por chapa (radial3d/panel_builder.gd, build_manual_*): el vertex shader las coloca con el mapa. Así ningún
// fotograma rehace mallas; solo se sube la textura cuando el mapa cambia.
// Atributos: UV = (u, v) en mm (en paredes, fondo y rebabas, v es el lado: −1 o +1), UV2 = (profundidad o papel del
// vértice, tipo de cara: 0 pintada · 1 interior · 2 canto · 3 pared · 4 rebaba · 5 hilo · 6 fondo), CUSTOM0 (rebabas) =
// (salida lateral, caída, cara: 1 de salida · 0 pintada, 0) por unidad de altura de la rebaba.
// Compatible con Forward+, Mobile y Compatibility: sin CLEARCOAT, sin texturas de pantalla ni arrays de uniformes.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ── El mapa del surco ──
uniform sampler2D cut_map : filter_nearest, repeat_disable;
uniform float line_mm = 230.0;   // la textura va de u = 0 a line_mm
uniform float n_samples = 921.0;
uniform float total_mm = 1.035;  // lo que se dibuja: pintura + chapa + cataforesis interior (esta, solo de dibujo)
uniform float through_mm = 1.01; // el espesor del modelo (chapa + pintura): con esa profundidad, el disco la atraviesa
uniform vec4 layers_mm = vec4(0.045, 0.060, 0.085, 0.110);
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
uniform float is_plastic = 0.0;
uniform float inner_ecoat = 1.0;
uniform float mark_line = 1.0;       // línea de corte marcada en la pintura (discontinua)

// ── Calor ──
uniform float temp_c = 1250.0;       // temperatura del borde del surco al cortar (del modelo)
uniform int tint_mode = 0;           // 0 acero (revenido) · 1 aluminio (gris mate) · 2 plástico (fundido)
uniform vec3 tint_color : source_color = vec3(0.64, 0.67, 0.69);
uniform sampler2D temper_ramp : source_color, filter_linear, repeat_disable;
uniform float temper_min_c = 150.0;
uniform float temper_max_c = 450.0;
uniform sampler2D heat_ramp : source_color, filter_linear, repeat_disable;
uniform float glow_c = 0.0;          // temperatura del frente del corte ahora (0: no brilla)
uniform float glow_u_mm = 0.0;       // dónde está el frente del corte (u)
uniform float section_emission = 0.12;

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

// Muestra del mapa más próxima a u (centro del texel de la muestra round(u/Δu)).
vec2 map_uv(float u, float row) {
	float x = (clamp(u, 0.0, line_mm) / max(line_mm, 1e-3) * (n_samples - 1.0) + 0.5) / n_samples;
	return vec2(x, row);
}

vec4 row0(float u) {
	return texture(cut_map, map_uv(u, 0.25));
}

vec4 row1(float u) {
	return texture(cut_map, map_uv(u, 0.75));
}

// ¿Atraviesa la chapa el surco de esa profundidad (la del modelo)? Si sí, se dibuja hasta la cara interior.
bool is_through(float d_cut) {
	return d_cut >= through_mm - 0.001;
}

float draw_depth(float d_cut) {
	return is_through(d_cut) ? total_mm : min(d_cut, total_mm);
}

vec4 temper(float t) {
	float k = clamp((t - temper_min_c) / (temper_max_c - temper_min_c), 0.0, 1.0);
	return texture(temper_ramp, vec2(k, 0.5));
}

vec3 incandescence(float t) {
	float k = clamp((t - 300.0) / 1000.0, 0.0, 1.0);
	return texture(heat_ramp, vec2(k, 0.5)).rgb;
}

// Temperatura máxima alcanzada a d mm del borde del surco, con la zona > 200 °C de ese punto (haz, mm).
float temp_at(float d, float haz) {
	if (haz <= 0.0) {
		return 20.0;
	}
	float lam = haz;
	if (temp_c > 205.0) {
		lam = haz / max(log((temp_c - 20.0) / 180.0), 0.05);
	}
	return 20.0 + (temp_c - 20.0) * exp(-d / max(lam, 0.05));
}

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
	float face = UV2.y;
	if (face > 2.5 && face < 4.5 || face > 5.5) {
		// Pared (3), rebaba (4) o fondo (6): el vértice está en la línea central; se coloca con el mapa del surco
		float u = UV.x;
		float side = UV.y < 0.0 ? -1.0 : 1.0;
		vec4 r0 = row0(u);
		float d_cut = draw_depth(r0.x);
		float half_w = r0.y;
		float tt = r0.z;
		float v;
		float d;
		if (face < 3.5 || face > 5.5) {
			d = UV2.x * d_cut;  // pared: arriba (0) o abajo (1); fondo: abajo
			v = side * half_w + tt * d;
			// La pared mira hacia dentro del surco
			vec3 down_dir = normalize(-NORMAL + vec3(0.0, 0.0, tt));
			vec3 wn = normalize(cross(vec3(1.0, 0.0, 0.0), down_dir));
			if (wn.z * side > 0.0) {
				wn = -wn;
			}
			if (face > 5.5) {
				wn = NORMAL;
			}
			VERTEX += vec3(0.0, 0.0, v / 1000.0) - NORMAL * (d / 1000.0);
			NORMAL = wn;
		} else {
			// Rebaba: labio que cuelga del borde del surco en la cara de salida (o cordón fundido en la pintada)
			vec4 r1 = row1(u);
			float h = side < 0.0 ? r0.w : r1.x;
			bool exit_face = CUSTOM0.z > 0.5;
			float face_d = exit_face ? total_mm : 0.0;
			float down = exit_face ? 1.0 : -1.0;
			float hh = h * (exit_face ? 1.0 : 0.6);
			v = side * half_w + tt * face_d + side * CUSTOM0.x * hh;
			d = face_d + down * CUSTOM0.y * hh;
			VERTEX += vec3(0.0, 0.0, v / 1000.0) - NORMAL * (d / 1000.0);
		}
		v_uv = vec2(u, v);
		v_depth = d;
	}
}

void fragment() {
	float face = v_face;
	float depth = v_depth;
	vec2 uv = v_uv;
	vec4 r0 = row0(uv.x);
	vec4 r1 = row1(uv.x);
	float d_cut = r0.x;
	float half_w = r0.y;
	float tt = r0.z;
	float burn = r1.y;
	float haz = r1.z;
	float dv = abs(uv.y - tt * depth) - half_w;  // < 0 dentro del surco
	bool cut_here = d_cut > 0.001;

	// El surco se abre donde el mapa dice que se ha cortado
	if (face < 0.5) {
		if (cut_here && dv < 0.0) {
			discard;
		}
	} else if (face < 1.5) {
		if (is_through(d_cut) && dv < 0.0) {
			discard;
		}
	} else if (face < 2.5) {
		if (dv < 0.0 && depth < draw_depth(d_cut)) {
			discard;
		}
	} else if (face > 5.5) {
		// fondo de un surco que aún no atraviesa la chapa
		if (!cut_here || is_through(d_cut)) {
			discard;
		}
	} else if (face > 4.5) {
		// hilos de plástico: solo donde el disco atravesó y fundió la chapa
		if (!is_through(d_cut) || hash21(vec2(floor(uv.x * 2.0), 1.7)) > r1.w) {
			discard;
		}
	} else if (face > 2.5 && face < 3.5) {
		if (!cut_here) {
			discard;
		}
	}

	float dist = max(dv, 0.0);
	float n1 = vnoise(uv * 2.2);
	float n2 = vnoise(uv * 14.0 + vec2(depth * 7.0));
	float t_here = temp_at(dist, haz);
	float s = burn > 0.0 ? dist / burn : 2.0;  // 0 en el borde del surco, 1 donde acaba la pintura quemada

	vec3 core = mix(metal_lo, metal_color, 0.55 + 0.45 * n1);
	vec3 albedo;
	float rough;
	float metallic;
	float spec = 0.5;
	vec3 emit = vec3(0.0);

	if (face < 1.5) {
		// ── Caras: pintada (0) o interior (1) ──
		bool outer = face < 0.5;
		vec3 coat;
		if (outer) {
			coat = mix(paint_lo, paint_color, 0.7 + 0.3 * n1);
			float sparkle = step(0.9975, hash21(floor(uv * 7.0)));
			coat = mix(coat, flake_color, sparkle * flake * 0.35);
			rough = 0.3;
			spec = 0.35;
			// Línea de corte marcada (discontinua, de rotulador) donde aún no hay surco
			if (mark_line > 0.5 && !cut_here && abs(uv.y) < 0.3 && fract(uv.x / 6.0) < 0.62) {
				coat = mix(coat, vec3(0.93, 0.92, 0.88), 0.85);
			}
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
		} else if (!outer && haz > 0.0 && inner_ecoat < 0.5) {
			albedo = heated_core(core, t_here, n2);
		}
	} else if (face < 3.5 || face > 5.5) {
		// ── Canto (2), paredes (3) y fondo (6) del surco: la sección de las capas ──
		bool wall = face > 2.5;
		float dh = wall ? 0.0 : dist;
		float th = temp_at(dh, max(haz, 0.3));
		float char_k = burn > 0.0 ? smoothstep(burn, burn * 0.15, dh) : 0.0;
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
			float marks = 0.5 + 0.5 * sin(uv.x * 9.0 + depth * 30.0 + n2 * 3.0);
			layer *= 0.82 + 0.3 * marks;
		}
		albedo = layer;
		metallic = lm * (is_plastic > 0.5 ? 0.0 : (wall ? 0.6 : 0.3));
		rough = lm > 0.5 ? (wall ? 0.45 : 0.7) : 0.6;
		if (!wall) {
			emit += albedo * section_emission;
		}
	} else if (face < 4.5) {
		// ── Rebaba ──
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

	// Incandescencia del frente del corte (solo el acero brilla), donde el disco está cortando ahora
	if (glow_c > 0.0 && cut_here) {
		float along = abs(uv.x - glow_u_mm);
		float g = glow_c * exp(-along / 1.6);
		if (face < 1.5) {
			g *= exp(-dist / 0.35);
		}
		emit += incandescence(g) * 2.2 * smoothstep(420.0, 700.0, g);
	}

	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
