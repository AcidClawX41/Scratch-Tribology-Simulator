// Capas de pelo del contorno (unidad 4l): la misma malla del pelo, hinchada a lo largo de su normal una fracción
// shell_k del largo del pelo, con las puntas de pelo (strands) que sobreviven cada vez menos hacia fuera. De frente se
// ven como un moteado de pelos; en el contorno, como un borde peludo. El alfa del color de los vértices da el largo del
// pelo en cada sitio (corto en la cara y las patas); bristle lo alarga (el pelo erizado) y el viento dobla las puntas.
// Alfa recortada (opaco): sin orden de dibujo. Solo dibujo.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float strand_scale = 2.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 tip_tint : source_color = vec4(1.0);
uniform float shell_k = 0.5;
uniform float shell_len = 0.01;
uniform float bristle = 0.0;
uniform vec3 wind = vec3(-1.0, 0.0, 0.0);
uniform float flutter = 0.0;
uniform float anim_t = 0.0;
uniform float fade = 1.0;
uniform float roughness = 0.9;
uniform float rim = 0.5;
uniform float rim_tint = 0.5;
uniform float sheen = 0.25;

varying float v_len;

void vertex() {
	v_len = COLOR.a;
	float len = shell_len * (0.25 + 0.75 * COLOR.a) * (1.0 + 1.4 * bristle);
	float k = shell_k;
	vec3 w = length(wind) > 1e-4 ? normalize(wind) : vec3(-1.0, 0.0, 0.0);
	float ph = anim_t * 17.0 + dot(VERTEX, vec3(23.0, 19.0, 29.0));
	float g = 0.65 + 0.35 * sin(ph);
	vec3 nn = normalize(NORMAL);
	VERTEX += nn * len * k + w * len * k * k * (0.35 + 1.2 * flutter * g) + vec3(0.0, -1.0, 0.0) * len * k * k * 0.25;
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	float h = texture(strands, UV2 * strand_scale).r;
	if (h < 0.18 + 0.72 * shell_k || v_len < 0.05) {
		discard;
	}
	if (fade < 0.999 && bayer4(FRAGCOORD.xy) >= fade) {
		discard;
	}
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.rgb * tint.rgb;
	ALBEDO = mix(base * 0.85, base * tip_tint.rgb, shell_k);
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	RIM = rim;
	RIM_TINT = rim_tint;
	BACKLIGHT = base * sheen;
}
