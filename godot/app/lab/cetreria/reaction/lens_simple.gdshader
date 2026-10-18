// Cetrería · la lente de la cámara en el teléfono (unidad 5t-B, dibujo): la versión sencilla de lens.gdshader, sin leer la
// pantalla (sin refracción ni desenfoque): los rayones, las esquirlas, la grieta con su zona lechosa, la grasa y el polvo se
// dibujan encima con transparencia, y la pérdida de contraste de una lente muy rayada es una veladura clara donde están
// (obscuration). La viñeta de la lente de plástico, el destello del impacto y el paño, igual que en escritorio.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D damage_map : filter_linear, repeat_disable;
uniform vec2 map_px = vec2(640.0, 280.0);
uniform vec2 view_px = vec2(390.0, 440.0);
uniform bool has_damage = false;
uniform float obscuration = 0.0;
uniform float vignette = 0.0;
uniform float flash = 0.0;
uniform vec2 flash_at = vec2(0.5);
uniform float wipe = -1.0;

#include "res://app/lab/cetreria/reaction/lens_cloth.gdshaderinc"

vec4 part(vec2 uv, float k) {
	vec2 h = 0.5 / map_px;
	vec2 q = clamp(uv, h, vec2(1.0) - h);
	return texture(damage_map, vec2((k + q.x) / 3.0, q.y));
}

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	if (has_damage) {
		vec4 a = part(uv, 0.0);
		vec4 b = part(uv, 1.0);
		vec4 c = part(uv, 2.0);
		float wiped = wipe >= 0.0 ? 1.0 - smoothstep(cloth_edge(wipe) - 0.12, cloth_edge(wipe) - 0.06, uv.x) : 0.0;
		float grease = clamp(b.r * (1.0 - wiped), 0.0, 1.0);
		float haze = clamp(b.b, 0.0, 1.0);
		float milky = clamp(b.g, 0.0, 1.0);
		float ob = clamp(obscuration, 0.0, 1.0);
		// la veladura clara (lo que esparce la luz): rayones, lo lechoso y la grasa
		float veil = clamp(haze * (0.06 + 0.5 * ob) + milky * 0.42 + grease * 0.2, 0.0, 0.85);
		col = vec3(0.82, 0.84, 0.86);
		alpha = veil;
		// el surco (una línea fina algo clara), el borde blanquecino, las grietas y el polvo
		float line = clamp(a.r * 0.35 + a.g * 0.65 + a.b * 0.8 + smoothstep(0.8, 0.98, grease) * 0.6, 0.0, 0.92);
		col = mix(col, vec3(0.94, 0.95, 0.97), line);
		alpha = max(alpha, line);
		// lo que se queda pegado
		float dep = max(max(c.r, c.g), c.b);
		col = mix(col, c.rgb / max(dep, 1e-4), clamp(dep * 1.6, 0.0, 0.7));
		alpha = max(alpha, clamp(dep * 1.4, 0.0, 0.6));
	}
	// el paño
	vec4 cl = cloth(uv, wipe, view_px);
	col = mix(col, cl.rgb, cl.a / max(max(alpha, cl.a), 1e-4));
	alpha = max(alpha, cl.a);
	// la viñeta (la lente de plástico) y el destello
	vec2 d = (uv - 0.5) * vec2(view_px.x / max(view_px.y, 1.0), 1.0);
	float vig = vignette * smoothstep(0.2, 1.1, dot(d, d));
	col = mix(col, vec3(0.0), vig / max(alpha + vig, 1e-4) * step(0.0001, vig));
	alpha = alpha + vig * (1.0 - alpha);
	vec2 fd = (uv - flash_at) * vec2(view_px.x / max(view_px.y, 1.0), 1.0);
	float fl = flash * (0.3 + 0.7 * exp(-dot(fd, fd) * 9.0));
	col = mix(col, vec3(1.0), fl / max(alpha + fl, 1e-4) * step(0.0001, fl));
	alpha = alpha + fl * (1.0 - alpha);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
