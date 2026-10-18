// El campo verde del paisaje del coche en marcha (unidad 4x, scenery.gd): dos tiras a los lados de la carretera larga de la
// persecución, desde su arcén hasta lejos, que siguen su trazado (scenery_path.gdshaderinc). Hierba de tres tonos a parcelas
// (una más clara, una más oscura y una amarillenta), con grano fino y un relieve suave que crece al alejarse del arcén
// (plano junto a él). Lo que se mueve es la textura: el campo corre con lo recorrido (road_m), sin costuras. La lejanía la
// funde con el cielo la niebla del entorno (car_scene.gd). Solo dibujo. Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://app/lab/car3d/scenery_path.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.27, 0.42, 0.16);
uniform vec3 grass_b : source_color = vec3(0.17, 0.31, 0.12);
uniform vec3 grass_c : source_color = vec3(0.47, 0.46, 0.2);
uniform float edge_z = 8.4;  // donde acaba el arcén, de lado desde el eje de la carretera (m)
uniform float axis_z = -1.75;
uniform float relief_m = 2.4;  // el relieve de lejos (m)

varying vec2 v_q;
varying float v_far;

float relief(vec2 q, float side) {
	float ramp = smoothstep(0.0, 30.0, side);
	float hills = sc_noise(q * 0.012) * 0.7 + sc_noise(q * 0.035) * 0.3;
	float bumps = sc_noise(q * 0.25) * 0.15;
	return (hills * relief_m * ramp + bumps * smoothstep(0.0, 6.0, side)) - 0.04;
}

void vertex() {
	float a = VERTEX.x;
	float z = VERTEX.z;
	float side = max(abs(z - axis_z) - edge_z, 0.0);
	vec2 q = vec2(a + road_m, z);
	v_q = q;
	v_far = side;
	float inner;
	float head;
	vec3 w = scenery_place(a, z, inner, head);
	float y = relief(q, side);
	// la normal, del relieve en coordenadas de la carretera llevada al rumbo de ahí
	float e = 1.5;
	float dha = (relief(q + vec2(e, 0.0), side) - relief(q - vec2(e, 0.0), side)) / (2.0 * e);
	float sz = max(abs(z + e - axis_z) - edge_z, 0.0);
	float sm = max(abs(z - e - axis_z) - edge_z, 0.0);
	float dhz = (relief(q + vec2(0.0, e), sz) - relief(q - vec2(0.0, e), sm)) / (2.0 * e);
	vec3 t3 = vec3(cos(head), 0.0, -sin(head));
	vec3 n3 = vec3(sin(head), 0.0, cos(head));
	NORMAL = normalize(vec3(0.0, 1.0, 0.0) - dha * t3 - dhz * n3);
	VERTEX = vec3(w.x, y, w.z);
}

void fragment() {
	vec2 q = v_q;
	// parcelas: cada una con su tono (lindes rectas a lo largo y de través, algo torcidas)
	vec2 cell = floor(vec2(q.x / 46.0 + 0.2 * sin(q.y * 0.03), q.y / 31.0));
	float pick = sc_h21(cell + 7.0);
	vec3 col = pick < 0.45 ? grass_a : (pick < 0.82 ? grass_b : grass_c);
	// dentro de la parcela, manchas grandes y el grano fino (que se apaga de lejos: sin centelleo)
	col *= 0.82 + 0.3 * sc_noise(q * 0.09);
	float fine_vis = 1.0 - smoothstep(0.25, 1.0, fwidth(q.x * 2.0));
	col *= 1.0 + fine_vis * (0.18 * (sc_noise(q * 2.3) - 0.5) + 0.1 * (sc_noise(q * 9.0) - 0.5));
	// en las amarillentas, las hileras de la siega
	if (pick >= 0.82) {
		float rows = sin(q.y * 3.1416 / 0.9) * 0.5 + 0.5;
		col *= 1.0 - 0.12 * rows * (1.0 - smoothstep(0.5, 1.5, fwidth(q.y / 0.9)));
	}
	// las lindes: una franja algo más oscura
	vec2 fc = fract(vec2(q.x / 46.0 + 0.2 * sin(q.y * 0.03), q.y / 31.0));
	float hedge = 1.0 - smoothstep(0.0, 0.02, min(min(fc.x, 1.0 - fc.x), min(fc.y, 1.0 - fc.y)));
	col = mix(col, grass_b * 0.7, hedge * 0.6 * smoothstep(4.0, 12.0, v_far));
	// junto al arcén, la hierba más seca (la del arcén de road_curve.gdshader)
	col = mix(vec3(0.21, 0.23, 0.16), col, smoothstep(0.0, 3.0, v_far));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
