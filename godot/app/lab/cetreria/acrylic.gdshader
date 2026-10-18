// Cetrería · la reconstrucción con metacrilato y bicarbonato (dibujo): una capa dura y translúcida, blanquecina, con la
// forma de la garra de partida desde donde se rompió hasta la punta. UV.x = s (mm), como el estuche; se ve de from_s en
// adelante (con un borde de solape de overlap mm sobre lo que queda de garra).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float from_s = 0.0;
uniform float overlap = 1.5;
uniform vec3 color : source_color = vec3(0.93, 0.9, 0.86);
uniform float opacity = 0.62;

void fragment() {
	if (UV.x < from_s - overlap) {
		discard;
	}
	float edge = smoothstep(from_s - overlap, from_s, UV.x);
	float bubbles = step(0.985, fract(sin(dot(floor(vec2(UV.x * 6.0, UV.y * 30.0)), vec2(12.9898, 78.233))) * 43758.5453));
	ALBEDO = color * (1.0 - 0.08 * bubbles);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALPHA = clamp(opacity * edge + fres * 0.3, 0.0, 1.0);
}
