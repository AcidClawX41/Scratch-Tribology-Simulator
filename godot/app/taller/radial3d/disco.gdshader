// Disco de la radial: abrasivo aglomerado (fino o grueso), diamante segmentado, láminas o borde continuo de grano
// sobre un cuerpo de acero (metal duro y CBN).
// El giro no mueve la malla: el dibujo se gira en el shader con el ángulo que muestra la escena (`spin`), que a
// rpm altas es el de un estroboscopio (el disco parece girar despacio y se ve nítido) y `blur` emborrona el
// dibujo a lo largo del giro, como lo vería una cámara. La franja de color es la velocidad máxima de trabajo
// (EN 12413: 50 azul · 63 amarillo · 80 rojo · 100 verde).
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int kind = 0;               // 0 abrasivo · 1 diamante · 2 láminas · 3 borde continuo (metal duro, CBN)
uniform vec3 rim_color : source_color = vec3(0.43, 0.45, 0.48);  // grano del borde continuo
uniform float radius_mm = 62.5;
uniform float bore_mm = 11.11;
uniform float label_mm = 36.0;      // radio exterior de la etiqueta
uniform float spin = 0.0;           // ángulo mostrado (rad)
uniform float blur = 0.0;           // emborronado angular (rad)
uniform vec3 body : source_color = vec3(0.29, 0.23, 0.2);
uniform vec3 body_lo : source_color = vec3(0.17, 0.13, 0.11);
uniform vec3 label_color : source_color = vec3(0.91, 0.89, 0.85);
uniform vec3 label_ink : source_color = vec3(0.17, 0.18, 0.21);
uniform vec3 stripe : source_color = vec3(0.84, 0.2, 0.23);
uniform float loading = 0.0;        // embotamiento: metal o plástico pegado en el borde (0-1)
uniform vec3 loading_color : source_color = vec3(0.86, 0.89, 0.92);
uniform int segments = 12;
uniform float segment_mm = 8.0;
uniform int flaps = 72;

varying vec3 v_local;
varying float v_part;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_local = VERTEX;
	v_part = UV2.x;
}

// Dibujo de la cara a radio r (mm) y ángulo th (rad, ya en el marco del disco).
vec3 face_pattern(float r, float th, float part) {
	vec2 q = vec2(cos(th), sin(th)) * r;
	float grain = hash21(floor(q * 3.2));
	vec3 col = mix(body_lo, body, 0.35 + 0.65 * grain);
	if (kind == 0) {
		// tejido de fibra de vidrio bajo la resina
		float mesh = step(0.82, abs(sin(q.x * 1.7))) + step(0.82, abs(sin(q.y * 1.7)));
		col *= 1.0 - 0.12 * clamp(mesh, 0.0, 1.0);
		if (part < 0.5 && r < label_mm) {
			col = label_color;
			float ring = step(abs(r - (label_mm - 1.2)), 0.35) + step(abs(r - (bore_mm + 3.2)), 0.3);
			// líneas de «texto» impresas alrededor de la etiqueta
			float band = step(abs(r - 31.0), 1.3);
			float word = floor(th * 5.0);
			float letters = step(0.35, fract(th * r * 0.28)) * step(0.25, hash21(vec2(floor(th * r * 0.28), 3.0)))
				* step(0.12, fract(th * 5.0)) * step(fract(th * 5.0), 0.8) * step(0.3, hash21(vec2(word, 7.0)));
			col = mix(col, label_ink, clamp(ring + band * letters * 0.85, 0.0, 1.0));
			// franja de velocidad máxima, de lado a lado de la etiqueta
			float w = abs(q.y);
			col = mix(col, stripe, step(w, 3.4) * step(0.0, q.x));
		}
	} else if (kind == 1) {
		float rs = radius_mm - segment_mm;
		if (r < rs) {
			// alma de acero con ranuras de dilatación cortadas con láser
			col = mix(body_lo, body, 0.6 + 0.4 * grain);
			float slot = step(abs(fract(th * float(segments) / 6.2831853 + 0.5) - 0.5) * 6.2831853 * r / float(segments), 0.5)
				* step(rs - 9.0, r);
			col = mix(col, vec3(0.05), slot);
			if (r < label_mm && part < 0.5) {
				col = mix(col, label_color, 0.85);
				float ring = step(abs(r - (label_mm - 1.0)), 0.3);
				col = mix(col, label_ink, ring);
				col = mix(col, stripe, step(abs(q.y), 3.0) * step(0.0, q.x) * step(bore_mm + 2.0, r));
			}
		} else {
			// segmento: matriz metálica con cristales de diamante que brillan
			col = vec3(0.24, 0.25, 0.27) * (0.8 + 0.4 * grain);
			float gem = step(0.975, hash21(floor(q * 6.0)));
			col += vec3(0.7) * gem;
		}
	} else if (kind == 3) {
		float rs = radius_mm - segment_mm;
		if (r < rs) {
			// cuerpo de acero con las rayas del rectificado
			col = mix(body_lo, body, 0.6 + 0.4 * grain) * (0.93 + 0.07 * sin(r * 3.1));
			if (r < label_mm && part < 0.5 && r > bore_mm + 2.0) {
				col = mix(col, label_color, 0.85);
				col = mix(col, label_ink, step(abs(r - (label_mm - 1.0)), 0.3));
			}
		} else {
			// borde continuo de grano (metal duro soldado o CBN en resina) que brilla un poco
			col = rim_color * (0.8 + 0.4 * grain);
			col += vec3(0.55) * step(0.97, hash21(floor(q * 7.0)));
		}
	} else {
		if (part > 7.5) {
			// láminas de tela abrasiva solapadas como escamas, en abanico
			float a = th * float(flaps) / 6.2831853 + (r - 30.0) * 0.06;
			float f = fract(a);
			col = mix(body_lo, body, smoothstep(0.0, 0.85, f)) * (0.85 + 0.3 * grain);
			col *= 1.0 - 0.45 * smoothstep(0.9, 1.0, f);
		} else {
			col = vec3(0.1, 0.1, 0.11) * (0.8 + 0.4 * grain);
			if (r < label_mm && r > bore_mm + 1.0) {
				col = mix(col, label_color, 0.9);
				col = mix(col, stripe, step(abs(q.y), 3.0) * step(0.0, q.x));
			}
		}
	}
	// embotamiento: metal blando o plástico pegado cerca del borde
	float load_band = smoothstep(radius_mm - 9.0, radius_mm - 1.0, r);
	float smear = step(0.35, hash21(floor(vec2(th * 40.0, r * 0.7))));
	col = mix(col, loading_color * (0.8 + 0.3 * grain), loading * load_band * (0.55 + 0.45 * smear));
	return col;
}

void fragment() {
	float r = length(v_local.xy) * 1000.0;
	float th0 = atan(v_local.y, v_local.x) - spin;
	float part = v_part;
	// Segmentos del disco de diamante: huecos (gargantas) entre segmentos, con su ojo redondo.
	if (kind == 1 && r > radius_mm - segment_mm - 1.5 && blur < 0.2) {
		float cell = fract(th0 * float(segments) / 6.2831853);
		float arc = abs(cell - 0.5) * 6.2831853 * r / float(segments);  // mm al centro de la garganta
		float eye = length(vec2(arc, r - (radius_mm - segment_mm - 0.5)));
		if ((arc < 1.2 && r > radius_mm - segment_mm) || eye < 1.8) {
			discard;
		}
	}
	vec3 col = vec3(0.0);
	float taps = blur > 0.01 ? 5.0 : 1.0;
	for (int i = 0; i < 5; i++) {
		if (float(i) >= taps) {
			break;
		}
		float off = taps > 1.0 ? (float(i) / (taps - 1.0) - 0.5) * blur : 0.0;
		col += face_pattern(r, th0 + off, part);
	}
	col /= taps;
	float metal = 0.0;
	float rough = 0.75;
	if (part > 0.5 && part < 1.5) {
		// canto: el filo que corta, de grano o de segmento
		col = kind == 1 ? vec3(0.22, 0.23, 0.25) : (kind == 3 ? rim_color : body_lo * 1.2);
		col = mix(col, loading_color, loading * 0.8);
	} else if (part > 2.5 && part < 3.5) {
		col = vec3(0.55, 0.57, 0.6);
		metal = 0.8;
		rough = 0.35;
	}
	if ((kind == 1 || kind == 3) && r < radius_mm - segment_mm) {
		metal = 0.75;
		rough = 0.35;
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
}
