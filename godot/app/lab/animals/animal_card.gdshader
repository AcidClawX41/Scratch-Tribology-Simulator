// Tarjetas de plumas y mechones de los animales (unidad 4l): primarias y secundarias del ala abierta, rectrices, el
// plumaje erizado y los flecos lacios del casuario. Un cuadrilátero de dos caras con la silueta de la pluma (alfa de
// feather_tex, recortada) y el color de los vértices; la normal de la tarjeta es la del cuerpo donde nace (se ilumina
// como el plumaje, no como una hoja plana).
// - Erizado (bristle): la punta (alfa del color de los vértices = 1) se levanta a lo largo de la normal; en la base
//   (alfa 0) no se mueve.
// - Viento: la punta se agita en la dirección del aire (world_vertex_coords), con el tiempo de la pose.
// Solo dibujo.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform sampler2D feather_tex : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.75;
uniform float specular = 0.35;
uniform float rim = 0.35;
uniform float rim_tint = 0.6;
uniform float sheen = 0.2;
uniform float raise_m = 0.02;
uniform float bristle = 0.0;
uniform vec3 wind = vec3(-1.0, 0.0, 0.0);
uniform float flutter = 0.0;
uniform float wobble_m = 0.006;
uniform float anim_t = 0.0;
uniform float fade = 1.0;

void vertex() {
	float tip = COLOR.a;
	vec3 w = length(wind) > 1e-4 ? normalize(wind) : vec3(-1.0, 0.0, 0.0);
	float ph = anim_t * 19.0 + dot(VERTEX, vec3(29.0, 17.0, 23.0));
	float g = 0.6 * sin(ph) + 0.4 * sin(ph * 1.91 + 0.7);
	vec3 nn = normalize(NORMAL);
	VERTEX += nn * raise_m * bristle * tip + (w * (0.5 + 0.5 * g) + nn * 0.5 * g) * wobble_m * flutter * tip;
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec4 f = texture(feather_tex, UV);
	if (f.a < 0.5 || (fade < 0.999 && bayer4(FRAGCOORD.xy) >= fade)) {
		discard;
	}
	vec3 base = f.rgb * COLOR.rgb * tint.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	RIM = rim;
	RIM_TINT = rim_tint;
	BACKLIGHT = base * sheen;
}
