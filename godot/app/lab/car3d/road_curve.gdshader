// Carretera en curva del coche en marcha (unidades 4t y su pulido): el asfalto con su gravilla, la línea continua del
// borde, la discontinua del centro que corre con el coche, un bordillo rojo y blanco a cada lado y el arcén de tierra,
// todo siguiendo la curva. Solo dibujo (road_curve.gd).
// La malla es una tira recta: x es la distancia a lo largo de la carretera desde el coche (m) y z, la distancia al eje
// (m, + a la derecha del coche). En el vértice se lleva a su sitio con el eje de la carretera: path_p (BEND_N puntos en
// el plano xz del mundo, de x0 a x1 a lo largo) y path_h (el rumbo de cada uno: 0 hacia +x, + girando a la izquierda,
// hacia −z). Así la carretera conserva su ancho aunque dé media vuelta (una glorieta), cosa que un desplazamiento solo en
// z no hacía.
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

const int BEND_N = 64;

uniform sampler2D asphalt : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 path_p[BEND_N];
uniform float path_h[BEND_N];
uniform float x0 = -12.0;
uniform float x1 = 18.0;
uniform float road_m = 0.0;  // recorrido de la carretera (m): mueve la textura, las discontinuas y el bordillo
uniform float road_hw = 2.4;
uniform float axis_z = 0.0;  // dónde está el eje de la carretera respecto al coche (m, + a la derecha)
uniform float edge2 = 0.0;  // 1: también la línea continua del otro borde (la carretera entera, con el carril contrario)
uniform float edge_z = 2.05;
uniform float center_z = -2.05;
uniform float line_hw = 0.06;
uniform float dash_l = 1.0;
uniform float dash_gap = 2.0;
uniform float kerb_w = 0.35;
uniform float kerb_l = 1.0;
uniform vec3 paint_col : source_color = vec3(0.86, 0.85, 0.82);
uniform vec3 verge_col : source_color = vec3(0.2, 0.17, 0.2);  // tierra del arcén
uniform vec3 grass_col : source_color = vec3(0.21, 0.23, 0.16);  // hierba seca a manchas
uniform vec3 kerb_red : source_color = vec3(0.62, 0.12, 0.14);
uniform vec3 kerb_white : source_color = vec3(0.86, 0.85, 0.82);
uniform float tex_m = 1.6;  // metros por repetición de la textura del asfalto

// Ruido de valor (dibujo): manchas de hierba seca y tierra en el arcén y la gravilla suelta, sin textura.
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying float v_x;
varying float v_z;

void vertex() {
	v_x = VERTEX.x;
	v_z = VERTEX.z;
	float u = clamp((VERTEX.x - x0) / (x1 - x0), 0.0, 1.0) * float(BEND_N - 1);
	int i = int(floor(u));
	int j = min(i + 1, BEND_N - 1);
	float f = u - float(i);
	vec2 p = mix(path_p[i], path_p[j], f);
	float h = mix(path_h[i], path_h[j], f);
	// a la derecha del rumbo: (sen h, cos h) en (x, z)
	vec2 n = vec2(sin(h), cos(h));
	VERTEX.x = p.x + n.x * v_z;
	VERTEX.z = p.y + n.y * v_z;
}

void fragment() {
	float x = v_x + road_m;
	float z = v_z;
	float az = abs(z - axis_z);
	vec3 col = texture(asphalt, vec2(x, z) / tex_m).rgb;
	float rough = 0.9;
	// bordillo rojo y blanco justo fuera del asfalto, y el arcén de tierra después
	float kerb = step(road_hw, az) * (1.0 - step(road_hw + kerb_w, az));
	float stripe = step(mod(x, 2.0 * kerb_l), kerb_l);
	col = mix(col, mix(kerb_red, kerb_white, stripe), kerb);
	float verge = step(road_hw + kerb_w, az);
	if (verge > 0.5) {
		// el arcén: tierra con manchas de hierba seca (grandes y pequeñas), un grano fino y el borde con el bordillo más
		// oscuro (la tierra pisada)
		vec2 q = vec2(x, z);
		float patches = smoothstep(0.35, 0.75, vnoise(q * 0.45) * 0.65 + vnoise(q * 1.7) * 0.35);
		vec3 g = mix(verge_col, grass_col, patches);
		g *= 0.84 + 0.22 * vnoise(q * 6.0) + 0.1 * vnoise(q * 23.0);
		g *= mix(0.75, 1.0, smoothstep(0.0, 0.6, az - road_hw - kerb_w));
		col = g;
	}
	// línea continua del borde y discontinua del centro (con un borde suave de un par de centímetros)
	float aa = max(fwidth(z), 0.004);
	float edge = 1.0 - smoothstep(line_hw - aa, line_hw + aa, abs(z - edge_z));
	float edge_b = (1.0 - smoothstep(line_hw - aa, line_hw + aa, abs(z - (2.0 * axis_z - edge_z)))) * edge2;
	edge = max(edge, edge_b);
	float dash_on = step(mod(x, dash_l + dash_gap), dash_l);
	float center = (1.0 - smoothstep(line_hw - aa, line_hw + aa, abs(z - center_z))) * dash_on;
	float line = max(edge, center) * (1.0 - verge) * (1.0 - kerb);
	col = mix(col, paint_col, line);
	rough = mix(rough, 0.62, line);
	ALBEDO = col;
	ROUGHNESS = mix(mix(rough, 0.7, kerb), 1.0, verge);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
