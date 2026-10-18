// Superficie de los animales del coche en marcha (unidad 4l): plumas, pelo, escamas, piel desnuda y queratina con la
// luz física del coche y del taller (sol, cielo, sombras).
// - Color: el de los vértices (las zonas de cada especie) × el mapa del patrón en el UV de la pieza (rayas, barras;
//   blanco donde no hay) × la modulación de la tesela del detalle (UV2, en cm de la anatomía).
// - Relieve: el mapa de normales de la tesela (plumas en tejado, pelo, escamas, escudos, arrugas).
// - Plumas y pelo: rugosos, con luz de contorno (el cielo por detrás) y algo de luz que atraviesa el borde; queratina y
//   piel desnuda, más brillantes.
// - Viento (world_vertex_coords): lo suelto (alfa del color de los vértices) se agita en la dirección del aire, unos
//   milímetros, con una onda que depende del sitio; con el tiempo de la pose (anim_t), no del reloj: las capturas salen
//   iguales.
// - Desvanecerse sin pasar a transparente: tramado ordenado (fade < 1), sin problemas de orden de dibujo.
// Solo dibujo.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform sampler2D detail_albedo : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_mix = 0.5;
uniform float normal_depth = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.8;
uniform float specular = 0.35;
uniform float metallic = 0.0;
uniform float rim = 0.3;
uniform float rim_tint = 0.6;
uniform float sheen = 0.0;
uniform vec3 wind = vec3(-1.0, 0.0, 0.0);
uniform float flutter = 0.0;
uniform float wobble_m = 0.004;
uniform float anim_t = 0.0;
uniform float fade = 1.0;

void vertex() {
	if (flutter > 0.0 && COLOR.a > 0.0) {
		float ph = anim_t * 21.0 + dot(VERTEX, vec3(31.0, 23.0, 37.0));
		float g = 0.6 * sin(ph) + 0.4 * sin(ph * 2.13 + 1.7);
		vec3 w = length(wind) > 1e-4 ? normalize(wind) : vec3(-1.0, 0.0, 0.0);
		VERTEX += (w * (0.55 + 0.45 * g) + normalize(NORMAL) * 0.4 * g) * wobble_m * flutter * COLOR.a;
	}
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	if (fade < 0.999 && bayer4(FRAGCOORD.xy) >= fade) {
		discard;
	}
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.rgb * tint.rgb;
	float d = texture(detail_albedo, UV2).r;
	ALBEDO = base * mix(1.0, d, detail_mix);
	NORMAL_MAP = texture(detail_normal, UV2).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = metallic;
	RIM = rim;
	RIM_TINT = rim_tint;
	BACKLIGHT = base * sheen;
}
