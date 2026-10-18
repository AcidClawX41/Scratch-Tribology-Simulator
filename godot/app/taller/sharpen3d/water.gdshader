// Agua de la bandeja de la afiladora húmeda: lámina semitransparente con ondas suaves que mueve la piedra al girar.
// `phase` (s) la pone la escena con su propio reloj, no TIME, para que las capturas salgan iguales cada vez; `stir`
// (0-1) es cuánto remueve la piedra el agua (sigue a su giro). El agua se enturbia con el lodo del amolado (`murk`).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.46, 0.56, 0.6);
uniform vec3 murk_color : source_color = vec3(0.42, 0.42, 0.4);
uniform float murk = 0.35;
uniform float phase = 0.0;
uniform float stir = 1.0;
uniform float alpha = 0.62;

void fragment() {
	vec2 p = UV * vec2(42.0, 30.0);
	float a = sin(p.x + phase * 2.3 * stir) * cos(p.y * 1.3 - phase * 1.7 * stir);
	float b = sin(p.x * 0.7 - p.y * 1.1 + phase * 3.1 * stir);
	NORMAL = normalize(NORMAL + (TANGENT * a + BINORMAL * b) * 0.06 * (0.3 + stir));
	ALBEDO = mix(water_color, murk_color, murk);
	ALPHA = alpha;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
