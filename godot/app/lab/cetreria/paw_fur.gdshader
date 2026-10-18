// Cetrería · el pelo corto de los dedos y de la mano del tigre y del oso (unidad 5h, petición 37; dibujo hecho en código):
// pelo en capas (la técnica de las conchas: la misma malla repetida, cada capa un poco más fuera a lo largo de la normal y
// peinada hacia la punta del dedo), con miles de pelos finos recortados en cada capa: de cerca se ve pelo de verdad, no
// púas sueltas; con pocas capas (el teléfono, el nivel ligero), mechones peinados de varios píxeles (un pelo de un píxel
// recortado se ve como ruido). La capa 0 es la piel bajo el pelo (opaca, del color de la raíz). UV en milímetros
// (care_kit.gd: UV.x a lo largo, UV.y alrededor), UV2.y la altura de la capa (0-1). El color del vértice trae la
// oclusión horneada (R).
// Las rayas del tigre se pintan por la posición (en la mano, solo hacia el antebrazo).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 root_color : source_color = vec3(0.45, 0.25, 0.1);
uniform vec3 tip_color : source_color = vec3(0.86, 0.55, 0.24);
uniform vec3 belly_color : source_color = vec3(0.93, 0.86, 0.72);  // la cara de abajo y los lados de los dedos
uniform float fur_mm = 5.0;        // largo del pelo
uniform float strand_mm = 0.28;    // separación entre pelos
uniform float thick = 0.85;        // grosor de cada pelo en la raíz (fracción de la celda)
uniform float comb = 0.65;         // cuánto se peina hacia la punta (fracción del largo)
uniform vec3 comb_dir = vec3(1.0, 0.0, 0.0);  // hacia dónde (en el marco del objeto)
uniform float droop = 0.25;        // cuánto cae por su peso (fracción del largo)
uniform float stripes = 0.0;       // 1: rayas del tigre
uniform vec3 stripe_color : source_color = vec3(0.05, 0.04, 0.04);
uniform float stripe_mm = 28.0;
uniform vec2 stripe_axis = vec2(-1.0, 0.0);   // hacia dónde crecen las rayas (x, z del objeto)
uniform float stripe_from_m = 0.04;            // a partir de dónde (m, a lo largo de stripe_axis)
uniform float belly = 0.0;         // cuánto color claro abajo (0-1)
uniform float mass = 0.0;          // pocas capas (el teléfono, el detalle ligero): 0 pelos sueltos, 1 mechones
uniform float clump = 4.0;         // el ancho de un mechón, en pelos
uniform float clump_len = 2.2;     // lo largo que es un mechón (peinado a lo largo del dedo), en anchos

varying vec2 v_uv;
varying float v_h;
varying vec4 v_col;
varying vec3 v_obj;

void vertex() {
	v_uv = UV;
	v_h = UV2.y;
	v_col = COLOR;
	float h = UV2.y;
	float len = fur_mm * 0.001;
	vec3 dir = normalize(comb_dir - NORMAL * dot(comb_dir, NORMAL) + vec3(1e-5));
	VERTEX += NORMAL * h * len + dir * (h * h) * comb * len + vec3(0.0, -1.0, 0.0) * (h * h) * droop * len;
	v_obj = VERTEX;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float h = v_h;
	// con pocas capas no hay continuidad de una capa a otra, y un pelo de un píxel recortado se ve como ruido: en su
	// lugar, mechones de varios pelos peinados a lo largo del dedo (UV.x), llenos por dentro y más finos hacia fuera
	float k = mix(1.0, clump, mass);
	vec2 cell_mm = vec2(strand_mm * k * mix(1.0, clump_len, mass), strand_mm * k);
	vec2 p = v_uv / cell_mm;
	p.x += mass * hash12(vec2(floor(p.y), 7.0));
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float rnd = hash12(cell);
	float rnd2 = hash12(cell + 19.0);
	vec2 off = (vec2(rnd, rnd2) - 0.5) * 0.5 * (1.0 - 0.5 * mass);
	// cada pelo, con su largo (unos más cortos) y afinándose hacia la punta
	float own = mix(0.65 + 0.35 * rnd2, 1.0, mass);
	float px = max(length(fwidth(v_uv)), 1e-4) / (strand_mm * k);
	float r = 0.5 * thick * (1.0 - h / own);
	// de lejos (el pelo mide menos de un píxel) o con pocas capas, las capas se rellenan: el pelo se ve como una masa
	// con volumen (con mechones: la capa de dentro, llena; fuera, las puntas de los mechones)
	float fill = max(smoothstep(0.35, 1.2, px), mass);
	float r_clump = h < 0.55 ? 2.0 : (1.15 - h) * (0.8 + 0.4 * rnd);
	r = mix(r, mix(0.75 * (1.0 - h), r_clump, mass), fill);
	if (h > 0.001 && (length(f - off) > r || h > own)) {
		discard;
	}
	vec3 col = mix(root_color, tip_color, max(smoothstep(0.0, 1.0, h / own) * 0.9, 0.35 * mass) + 0.1 * rnd);
	// la cara de abajo y la de dentro, más clara (dibujo)
	col = mix(col, belly_color, belly * smoothstep(0.55, 0.95, v_col.g));
	if (stripes > 0.5) {
		float along = dot(v_obj.xz, normalize(stripe_axis)) - stripe_from_m;
		float ph = along / (stripe_mm * 0.001) * 6.2832 + 0.9 * sin(v_obj.y / (stripe_mm * 0.001) * 2.1);
		float w = sin(ph) + 0.35 * sin(ph * 2.0 + 1.1);
		float st = smoothstep(0.55, 0.75, w) * smoothstep(0.0, 0.02, along);
		col = mix(col, stripe_color, st);
	}
	// sombra propia del pelo: la raíz, más oscura (y la oclusión horneada de los pliegues); con mechones, lo que se ve
	// entre ellos es pelo de más abajo, no la piel: menos oscuro
	float self_shadow = mix(mix(0.45, 0.68, mass), 1.0, smoothstep(0.0, 0.85, h));
	ALBEDO = col * self_shadow * (0.35 + 0.65 * v_col.r);
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
