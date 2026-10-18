// Piezas del turismo pegadas a la chapa (unidad 4k): marcos y juntas de goma, cromados, tiradores, faldones, calandra,
// matrícula en blanco, faros y pilotos. Siguen la abolladura de la chapa (car_damage.gdshaderinc) para no quedarse
// flotando sobre un panel hundido. Dibujo: materiales físicos (PBR) con un patrón por pieza (pattern):
//   0 liso · 1 calandra (rejilla de lamas) · 2 plástico granulado · 3 matrícula en blanco (fondo retrorreflectante y
//   borde) · 4 faro (lente, parábolas cromadas y la tira de luz de día) · 5 piloto (lente roja con sus celdas; la luz de
//   freno sube la emisión) · 6 neumático del paso de rueda (guardabarros interior, granulado y oscuro).
// UV: la de la malla (en los parches del frontal, 0-1 a lo ancho y a lo alto).
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://app/lab/car3d/car_damage.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.05);
uniform float metallic = 0.0;
uniform float roughness = 0.5;
uniform int pattern = 0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float coat = 0.0;

varying vec3 v_obj;

float p_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_obj = VERTEX;
	if (n_dents > 0) {
		vec3 disp;
		vec3 grad;
		dent_field(VERTEX, disp, grad);
		VERTEX += disp;
		NORMAL = normalize(NORMAL + grad);
	}
}

void fragment() {
	vec3 col = albedo;
	float met = metallic;
	float rough = roughness;
	vec3 emit = emission_color * emission_energy;
	float cc = coat;
	vec2 uv = UV;
	if (pattern == 1) {
		// calandra: lamas horizontales sobre el hueco oscuro, con un marco
		float slat = smoothstep(0.35, 0.5, abs(fract(uv.y * 5.0) - 0.5) * 2.0);
		float frame = step(0.94, max(abs(uv.x * 2.0 - 1.0), abs(uv.y * 2.0 - 1.0)));
		col = mix(vec3(0.006), albedo, max(1.0 - slat, frame));
		rough = mix(0.9, roughness, max(1.0 - slat, frame));
	} else if (pattern == 2 || pattern == 6) {
		float g = p_hash(floor(v_obj.xy * 900.0) + floor(v_obj.z * 900.0));
		col = albedo * (0.9 + 0.2 * g);
		rough = roughness + 0.08 * g;
	} else if (pattern == 3) {
		// matrícula en blanco: fondo blanco retrorreflectante con el borde negro (sin letras: no es la de nadie)
		float edge = step(0.9, max(abs(uv.x * 2.0 - 1.0), abs(uv.y * 2.0 - 1.0) * 0.98));
		float band = step(uv.x, 0.09);
		col = mix(vec3(0.86, 0.87, 0.88), vec3(0.02), edge);
		col = mix(col, vec3(0.06, 0.12, 0.45), band * (1.0 - edge));
		rough = 0.45;
	} else if (pattern == 4) {
		// faro: dos parábolas cromadas bajo la lente y la tira de luz de día (LED) por debajo
		vec2 q = vec2(uv.x * 2.6, uv.y);
		float bowl = 1.0 - smoothstep(0.2, 0.42, length(vec2(fract(q.x) - 0.5, uv.y - 0.58)));
		col = mix(vec3(0.12, 0.12, 0.13), vec3(0.85, 0.87, 0.9), bowl);
		met = mix(0.2, 1.0, bowl);
		rough = mix(0.35, 0.08, bowl);
		float drl = 1.0 - smoothstep(0.08, 0.14, abs(uv.y - 0.2));
		emit = emission_color * emission_energy * drl + emission_color * emission_energy * 0.18 * bowl;
		cc = 1.0;
	} else if (pattern == 5) {
		// piloto: lente roja con celdas; la luz de posición y, al frenar, la de freno (emission_energy)
		float cell = smoothstep(0.42, 0.5, abs(fract(uv.x * 7.0) - 0.5)) * 0.35;
		col = albedo * (1.0 - cell);
		emit = emission_color * emission_energy * (0.75 + 0.25 * (1.0 - cell));
		rough = 0.12;
		cc = 1.0;
	}
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	EMISSION = emit;
	CLEARCOAT = cc;
	CLEARCOAT_ROUGHNESS = 0.05;
}
