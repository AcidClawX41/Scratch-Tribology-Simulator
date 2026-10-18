// Cetrería · la piel de los dedos y de las patas de cerca (unidad 5h, petición 37; dibujo hecho en código, sin texturas
// descargadas): los escudetes de arriba de los dedos de la rapaz y del velocirraptor, las escamas reticuladas de los
// lados, las papilas (o espículas) de las almohadillas, y la piel negra y rugosa de las almohadillas del tigre y del oso.
// Las coordenadas de la malla van en milímetros (care_kit.gd: UV.x a lo largo, UV.y alrededor), así que cada escama tiene
// su tamaño de verdad a cualquier distancia. El relieve sale de una altura calculada aquí y de sus derivadas en pantalla
// (Mikkelsen 2010, «Bump mapping unparametrized surfaces on the GPU»): un mapa de normales hecho en código. Se desvanece
// cuando la escama mide menos de unos píxeles (sin parpadeo de lejos). El color del vértice trae la oclusión horneada
// (R), la zona (G: 0 escudetes, 0,5 escamas, 1 almohadilla) y el bulto de la almohadilla (B).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 skin_a : source_color = vec3(0.89, 0.71, 0.23);   // la escama
uniform vec3 skin_b : source_color = vec3(0.55, 0.38, 0.1);    // el surco entre escamas
uniform vec3 pad_a : source_color = vec3(0.86, 0.69, 0.3);     // la almohadilla
uniform vec3 pad_b : source_color = vec3(0.5, 0.36, 0.14);     // el fondo entre papilas
uniform float scute_mm = 2.6;      // largo de cada escudete de arriba
uniform float scale_mm = 0.9;      // escamas reticuladas de los lados
uniform float papilla_mm = 0.45;   // papilas de la almohadilla
uniform float spicule = 0.0;       // 1: papilas afiladas (espículas)
uniform float relief_mm = 0.12;    // alto del relieve (mm)
uniform float rough_scale = 0.42;
uniform float rough_pad = 0.78;
uniform float sheen = 0.15;        // brillo de la queratina de la escama
uniform float detail = 1.0;        // 0: el teléfono (sin celdas: solo bandas)
uniform float leather = 0.0;       // 1: piel lisa de cuero (almohadillas de mamífero: arrugas en vez de escamas)

varying vec2 v_uv;
varying vec4 v_col;

void vertex() {
	v_uv = UV;
	v_col = COLOR;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Celdas de Voronoi en 2D: (distancia al centro más cercano, al segundo, valor de la celda).
vec3 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.15 + 0.7 * hash22(i + g);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash12(i + g + 7.0);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2, id);
}

void fragment() {
	vec2 p = v_uv;
	float zone = v_col.g;
	float ao = v_col.r;
	float px = max(length(fwidth(p)), 1e-4);  // mm por píxel
	// 1 · escudetes: placas de través, cada una monta sobre la siguiente hacia la punta
	float wob = 0.18 * scute_mm * sin(p.y / (2.3 * scute_mm) + floor(p.x / scute_mm) * 1.7);
	float fs = fract((p.x + wob) / scute_mm);
	float h_sc = smoothstep(0.0, 0.1, fs) * (0.5 + 0.5 * fs) * (1.0 - smoothstep(0.93, 1.0, fs));
	float tone_sc = hash12(vec2(floor((p.x + wob) / scute_mm), 3.0));
	float k_sc = smoothstep(0.45, 0.12, px / scute_mm);
	// 2 · escamas reticuladas (o arrugas del cuero)
	float h_rt = 0.5;
	float tone_rt = 0.5;
	float k_rt = 0.0;
	// 3 · papilas
	float h_pp = 0.5;
	float k_pp = 0.0;
	if (detail > 0.5) {
		vec3 vr = voronoi(p / scale_mm);
		h_rt = smoothstep(0.0, 0.22, vr.y - vr.x) * (0.75 + 0.25 * vr.z) + 0.25 * (1.0 - vr.x * vr.x);
		tone_rt = vr.z;
		k_rt = smoothstep(0.45, 0.12, px / scale_mm);
		vec3 vp = voronoi(p / papilla_mm + 17.0);
		float dome = 1.0 - smoothstep(0.05, 0.55, vp.x);
		h_pp = mix(dome, pow(dome, 3.0), spicule);
		k_pp = smoothstep(0.5, 0.15, px / papilla_mm);
	} else {
		h_rt = 0.5 + 0.5 * sin(p.x / scale_mm * 3.1416) * sin(p.y / scale_mm * 3.1416);
		k_rt = smoothstep(0.45, 0.12, px / scale_mm);
	}
	if (leather > 0.5) {
		// la almohadilla de un mamífero: piel gruesa con arrugas finas y granulada (sin escamas)
		float wr = sin(p.x / (scale_mm * 2.2) * 6.2832 + 2.0 * sin(p.y / (scale_mm * 3.1))) * 0.5 + 0.5;
		h_rt = mix(h_rt, wr, 0.5);
	}
	float h_scute = mix(0.5, h_sc, k_sc);
	float h_ret = mix(0.5, h_rt, k_rt);
	float h_pap = mix(0.5, h_pp, k_pp) * (0.7 + 0.6 * v_col.b);
	float w_sc = 1.0 - smoothstep(0.1, 0.4, zone);
	float w_pp = smoothstep(0.6, 0.9, zone);
	float w_rt = max(1.0 - w_sc - w_pp, 0.0);
	float h = h_scute * w_sc + h_ret * w_rt + h_pap * w_pp;
	// color: la escama y su surco, con un poco de variación de una a otra; la almohadilla, aparte
	float groove = w_sc * (1.0 - smoothstep(0.0, 0.25, h_sc)) * k_sc + w_rt * (1.0 - smoothstep(0.1, 0.45, h_rt)) * k_rt;
	vec3 scale_col = mix(skin_a, skin_b, groove * 0.62);
	scale_col *= 0.92 + 0.16 * mix(tone_rt, tone_sc, w_sc) * (w_sc * k_sc + w_rt * k_rt);
	vec3 pad_col = mix(pad_b, pad_a, mix(0.7, 0.45 + 0.55 * h_pp, k_pp));
	vec3 col = mix(scale_col, pad_col, w_pp);
	ALBEDO = col * (0.35 + 0.65 * ao);
	float rough = mix(mix(rough_scale, 0.72, groove), rough_pad, w_pp);
	ROUGHNESS = rough;
	SPECULAR = 0.35 + sheen * (1.0 - w_pp) * (1.0 - groove);
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	// el relieve: la altura en metros y su gradiente en pantalla
	float hm = (h - 0.5) * relief_mm * 0.001;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(hm);
	float dhdy = dFdy(hm);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	vec3 nb = normalize(abs(det) * NORMAL - grad);
	NORMAL = mix(NORMAL, nb, step(1e-14, abs(det)));
}
