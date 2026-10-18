// Cetrería · el estuche de la garra (queratina) o el material de una garra reforjada. La malla sale del perfil de
// ClawCare (claw_mesh.gd): UV.x = s (mm desde la base), UV.y = vuelta alrededor de la línea media (0 arriba, la cara
// dorsal), UV2.x = radio (mm). El color, el brillo y la luz de cada material son los de la biblioteca de materiales de
// las garras (unidad 5e: app/common/claw_material.gdshaderinc, con los datos ópticos de core/lab/claw_optics.gd; los
// parámetros claw_* los pone claw_look.gd): la queratina de cada especie con sus líneas de crecimiento, las capas del
// estuche, las estrías y su barniz; el reflejo medido de cada metal; el índice, el fuego y la absorción de cada gema.
// Encima, todo lo que da el estado (dibujo de lo que dice el motor):
// - la superficie que deja cada pasada (surface_tex, del contrato «La cetrería en alta definición y la superficie de la
//   garra»: la rugosidad, el rayado en su dirección, el quemado y los desconchones), que lee la biblioteca;
// - la queratina translúcida: en las garras claras deja ver la carne viva a trasluz (opacity < 1 y la carne viva dibujada
//   dentro), más fina y más translúcida en la punta;
// - el calor, como en una cámara térmica (de los nodos de temperatura de la instantánea; la queratina a 45 °C no cambia
//   de color de verdad: es una ayuda para ver dónde está caliente);
// - las grietas del cortaúñas (una raja por la cara dorsal, roja si llega a la carne viva) y las escamas de un deshojado;
// - la sangre, el polvo hemostático, la crema, la humedad y la mancha oscura del corte cerca de la carne viva;
// - el resaltado del tutorial (una franja de s que late).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://app/common/claw_material.gdshaderinc"

uniform float opacity = 0.97;
uniform float rim_k = 0.6;
uniform float apex_mm = 38.0;
uniform float flat_r = 0.0;
uniform sampler2D heat_tex : filter_linear, repeat_disable;
uniform vec2 heat_range = vec2(0.0, 40.0);
uniform float heat_on = 0.0;
uniform vec2 hi_band = vec2(0.0, 0.0);
uniform vec3 hi_color : source_color = vec3(0.95, 0.72, 0.3);
uniform float hi_on = 0.0;
uniform float time = 0.0;
uniform float blood = 0.0;
uniform float blood_from = 0.0;
uniform float powder = 0.0;
uniform float cream = 0.0;
uniform float wet = 0.0;
uniform float disinfected = 0.0;
uniform vec4 cracks[4];
uniform int crack_n = 0;
uniform vec4 peels[4];
uniform int peel_n = 0;
uniform float sign_k = 0.0;

varying float v_s;
varying float v_a;
varying float v_r;

void vertex() {
	v_s = UV.x;
	v_a = UV.y;
	v_r = UV2.x;
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// Distancia angular (en vueltas) a la línea dorsal, con un zigzag.
float dorsal_dist(float a, float s, float seed) {
	float wob = 0.01 * sin(s * 11.0 + seed * 7.0) + 0.006 * sin(s * 37.0 + seed);
	return abs(fract(a + 0.5 + wob) - 0.5);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 ts;
	vec3 ta;
	claw_tangents(n, VERTEX, vec2(v_s, v_a), ts, ta);
	vec3 none[3] = vec3[3](vec3(0.0), vec3(0.0), vec3(0.0));
	// el material (la biblioteca): queratina, metal, gema o cerámica, con su acabado o la superficie de cada pasada
	ClawOut o = claw_shade(n, VIEW, ts, ta, v_s, v_a, v_r, apex_mm, INV_VIEW_MATRIX, none, false);
	vec3 col = o.albedo;
	float rough = o.rough;
	float alpha_k = opacity;
	// lo que tapa el material (sangre, polvo, una raja, una escama): ni metal, ni brillo de gema, ni barniz
	float cover = 0.0;
	if (claw_kind == 0) {
		// la punta, más translúcida (la queratina es más fina)
		float tipk = smoothstep(apex_mm - 4.0, apex_mm, v_s) * claw_growth;
		alpha_k = mix(alpha_k, alpha_k * 0.85, tipk);
	}
	// escamas levantadas (deshojado): parches claros y ásperos
	for (int i = 0; i < peel_n; i++) {
		vec4 p = peels[i];
		if (v_s >= p.x && v_s <= p.y) {
			float cell = floor(v_s / 0.7) * 13.0 + floor(v_a * 18.0);
			float flake = step(0.45, hash11(cell + float(i) * 5.0));
			col = mix(col, col * 1.6 + vec3(0.12, 0.1, 0.08), flake * 0.7);
			rough = mix(rough, 0.85, flake);
			cover = max(cover, flake * 0.7);
		}
	}
	// grietas del cortaúñas: una raja por la cara dorsal (y otra ventral más corta)
	for (int i = 0; i < crack_n; i++) {
		vec4 c = cracks[i];
		if (v_s >= c.x && v_s <= c.y) {
			float fade = smoothstep(c.x, c.x + 0.6, v_s);
			float d1 = dorsal_dist(v_a, v_s, float(i));
			float d2 = dorsal_dist(fract(v_a + 0.5), v_s, float(i) + 3.0);
			float w = 0.012 * fade;
			float line = max(1.0 - smoothstep(w * 0.4, w, d1), (1.0 - smoothstep(w * 0.3, w * 0.8, d2)) * step(c.x + 0.5 * (c.y - c.x), v_s));
			vec3 cc = c.z > 0.5 ? vec3(0.42, 0.02, 0.03) : vec3(0.015, 0.012, 0.01);
			col = mix(col, cc, line);
			rough = mix(rough, 0.9, line);
			alpha_k = mix(alpha_k, 1.0, line);
			cover = max(cover, line);
		}
	}
	// humedad: más oscura y brillante; crema: brillo de grasa; clorhexidina: un velo
	col *= 1.0 - 0.18 * wet;
	rough = mix(rough, 0.1, max(wet * 0.7, cream * 0.9));
	col = mix(col, col + vec3(0.03, 0.01, 0.015), disinfected * 0.5);
	// la mancha oscura en el centro del corte, cerca de la carne viva
	float face = step(apex_mm - 0.05, v_s) * step(v_r, flat_r + 0.001);
	float centre = 1.0 - smoothstep(0.0, max(flat_r * 0.6, 0.05), v_r);
	float mark = sign_k * face * centre * 0.85;
	col = mix(col, vec3(0.05, 0.02, 0.02), mark);
	cover = max(cover, mark);
	// polvo hemostático en la punta
	float near_tip = smoothstep(apex_mm - 3.5, apex_mm - 0.3, v_s);
	float grain = hash11(floor(v_s * 9.0) * 31.0 + floor(v_a * 40.0));
	float pw = powder * near_tip;
	col = mix(col, vec3(0.55, 0.36, 0.12) * (0.8 + 0.4 * grain), pw * 0.85);
	rough = mix(rough, 0.95, pw);
	cover = max(cover, pw);
	// sangre
	float bl = blood * smoothstep(blood_from - 1.5, blood_from + 0.5, v_s);
	col = mix(col, vec3(0.45, 0.02, 0.03), bl * 0.9);
	rough = mix(rough, 0.08, bl);
	alpha_k = mix(alpha_k, 1.0, bl);
	cover = max(cover, bl * 0.9);
	// lo que tapa un metal no refleja como metal (METALLIC, abajo) y tapa la luz que sale de dentro de una gema
	vec3 emit = o.emission * (1.0 - cover);
	// calor, como en una cámara térmica (ayuda de dibujo)
	if (heat_on > 0.5) {
		float u = clamp((v_s - heat_range.x) / max(heat_range.y - heat_range.x, 0.001), 0.0, 1.0);
		float h = texture(heat_tex, vec2(u, 0.5)).r;
		vec3 hc = mix(vec3(1.0, 0.85, 0.25), vec3(1.0, 0.18, 0.05), smoothstep(0.2, 0.55, h));
		hc = mix(hc, vec3(1.0, 0.95, 0.9), smoothstep(0.7, 1.0, h));
		float k = smoothstep(0.03, 0.25, h);
		col = mix(col, hc, k * 0.8);
		emit += hc * k * 0.55;
		alpha_k = mix(alpha_k, 1.0, k * 0.6);
		cover = max(cover, k * 0.8);
	}
	// resaltado del tutorial: la franja [hi_band.x, hi_band.y] late
	if (hi_on > 0.5 && v_s >= hi_band.x && v_s <= hi_band.y) {
		// la zona late con un brillo en el borde (de cara a la cámara apenas cambia el color de la garra)
		float pulse = 0.55 + 0.45 * sin(time * 4.0);
		float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 1.5);
		float ends = 1.0 - smoothstep(0.0, 0.35, min(v_s - hi_band.x, hi_band.y - v_s));
		emit += hi_color * pulse * (0.08 + 0.5 * rim + 0.35 * ends);
		col = mix(col, hi_color, 0.06 * pulse);
	}
	NORMAL = o.normal;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = o.metal * (1.0 - cover);
	SPECULAR = mix(o.spec, 0.5, cover);
	EMISSION = emit;
	BACKLIGHT = col * o.backlight;
	CLEARCOAT = o.clearcoat * (1.0 - cover) * (1.0 - wet * 0.5);
	CLEARCOAT_ROUGHNESS = claw_clearcoat_rough;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.0);
	ALPHA = clamp(alpha_k + (1.0 - alpha_k) * fres * rim_k, 0.0, 1.0);
}
