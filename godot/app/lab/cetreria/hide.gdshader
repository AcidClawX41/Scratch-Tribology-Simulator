// Cetrería · la piel de la pata o de la mano (dibujo): escamas de rapaz o de dinosaurio (celdas en relieve) y pelo de
// tigre o de oso (fibra, con las rayas del tigre). Coordenadas del modelo en m (cell_m: tamaño de la escama o de la
// mecha), para que el dibujo no dependa de las UV de cada primitiva.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int kind = 0;                  // 0 escamas · 1 pelo
uniform vec3 color_a : source_color = vec3(0.85, 0.7, 0.25);
uniform vec3 color_b : source_color = vec3(0.6, 0.45, 0.15);
uniform float cell_m = 0.003;
uniform float stripes = 0.0;           // rayas del tigre (0 sin rayas)
uniform float stripe_m = 0.03;
uniform vec3 stripe_color : source_color = vec3(0.06, 0.05, 0.05);
uniform float roughness_k = 0.7;
uniform float sheen = 0.0;
uniform float detail = 1.0;            // 0: dibujo barato para el teléfono (sin celdas de Voronoi)

varying vec3 v_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Celdas de Voronoi: distancia al centro más cercano y al segundo (para el borde de la escama).
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash31(i + g), hash31(i + g + 17.0), hash31(i + g + 31.0));
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d1, d2);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	vec3 col;
	float rough = roughness_k;
	if (kind == 0 && detail < 0.5) {
		vec3 q = v_pos / cell_m;
		float e = abs(sin(q.x * 3.1416) * sin(q.y * 3.1416 + q.z * 1.7));
		col = mix(color_b, color_a, smoothstep(0.1, 0.5, e));
	} else if (kind == 0) {
		vec2 c = cells(v_pos / cell_m);
		float edge = smoothstep(0.02, 0.12, c.y - c.x);
		float tone = hash31(floor(v_pos / cell_m) + 3.0);
		col = mix(color_b, color_a, edge) * (0.9 + 0.2 * tone);
		rough = mix(0.85, roughness_k, edge);
	} else {
		vec3 q = v_pos / cell_m;
		float fib = hash31(floor(q * vec3(1.0, 1.0, 4.0)));
		col = mix(color_b, color_a, 0.35 + 0.65 * fib);
		if (stripes > 0.0) {
			// bandas de través (a lo largo de X va el brazo), con el borde ondulado y de grosor desigual
			float ph = v_pos.x / stripe_m * 6.2832 + 0.9 * sin(v_pos.z / stripe_m * 1.3) + 0.6 * sin(v_pos.y / stripe_m * 1.7);
			float w = sin(ph) + 0.35 * sin(ph * 2.0 + 1.1);
			float st = smoothstep(0.45, 0.65, w) * stripes;
			col = mix(col, stripe_color, st);
		}
		rough = 0.9;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3 + sheen * 0.4;
}
