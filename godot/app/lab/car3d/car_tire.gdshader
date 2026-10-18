// Neumático del turismo del coche en marcha (unidad 4k): 225/45 R17, con el flanco abombado y la banda de rodadura con
// sus tacos y sus surcos, y, en el coche clásico, la banda blanca del flanco. Al girar deprisa, los tacos se emborronan
// (blur, el mismo que desenfoca los radios de la llanta): no hay efecto estroboscópico porque lo que se ve con el
// desenfoque no depende del ángulo.
// UV: x = ángulo (0-1), y = posición en el perfil (0 talón de dentro · 0,36-0,64 la banda · 1 talón de fuera).
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 rubber : source_color = vec3(0.07, 0.068, 0.075);
uniform float blur = 0.0;
uniform float whitewall = 0.0;
uniform float blocks = 72.0;

void fragment() {
	float v = UV.y;
	float tread = smoothstep(0.33, 0.37, v) * (1.0 - smoothstep(0.63, 0.67, v));
	float stag = v > 0.5 ? 0.5 : 0.0;
	float blk = smoothstep(0.42, 0.5, abs(fract(UV.x * blocks + stag) - 0.5));
	float groove = 1.0 - smoothstep(0.012, 0.02, abs(v - 0.5));
	float pat = max(blk * 0.5, groove);
	float sharp = 1.0 - clamp(blur, 0.0, 1.0);
	vec3 col = rubber * (1.0 - tread * mix(0.25, pat * 0.55, sharp));
	// flanco: algo más brillante hacia el borde de la llanta (el caucho satinado del flanco)
	float side = 1.0 - tread;
	float wall = smoothstep(0.78, 0.8, v) * (1.0 - smoothstep(0.9, 0.92, v)) * whitewall;
	col = mix(col, vec3(0.86, 0.85, 0.82), wall);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.72, side) - wall * 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
