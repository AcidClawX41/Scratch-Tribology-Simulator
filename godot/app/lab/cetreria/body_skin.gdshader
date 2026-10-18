// Cetrería · lo que no lleva pelo ni plumas en los cuerpos de alta definición (unidad 5i, petición 37; dibujo hecho en
// código), con su relieve hecho aquí (mapa de normales de las derivadas en pantalla, como en paw_skin.gdshader):
//   0 queratina del pico: lisa y brillante, con las líneas de crecimiento y la punta más oscura;
//   1 piel de ave (la cera, la comisura y el anillo del ojo): fina y algo granulada;
//   2 escamas (los velocirraptores): escamas redondeadas de scale_mm con tubérculos, más grandes en el lomo, y las rayas
//      del de película por dónde están en el cuerpo (UV2);
//   3 la trufa de los mamíferos: empedrado fino y húmedo;
//   4 la lengua: rosada, con papilas y húmeda;
//   5 los labios y las encías: piel lisa y oscura;
//   6 los párpados: la piel con el borde oscuro (UV.x, desde el borde, en mm).
// UV en mm (body_kit.gd) · UV2 = (dónde está en el cuerpo, la vuelta) · COLOR = (oclusión, zona, —, cuánto respira).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;
uniform vec3 color_a : source_color = vec3(0.25, 0.25, 0.27);
uniform vec3 color_b : source_color = vec3(0.08, 0.08, 0.09);
uniform vec3 stripe_color : source_color = vec3(0.2, 0.17, 0.11);
uniform float stripes = 0.0;
uniform float stripe_n = 34.0;
uniform float scale_mm = 3.0;
uniform float relief_mm = 0.3;
uniform float rough = 0.4;
uniform float spec = 0.5;
uniform float tip_from = 0.6;        // queratina: dónde empieza a oscurecerse la punta (UV.x relativo, con len_mm)
uniform float len_mm = 50.0;
uniform float rim_mm = 1.2;          // párpado: el ancho del borde oscuro
uniform float breath = 0.0;
uniform float breath_mm = 4.0;
uniform float detail = 1.0;

varying vec2 v_uv;
varying vec2 v_uv2;
varying vec4 v_col;

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

void vertex() {
	v_uv = UV;
	v_uv2 = UV2;
	v_col = COLOR;
	VERTEX += NORMAL * (breath * COLOR.a * breath_mm * 0.001);
}

void fragment() {
	vec2 p = v_uv;
	float px = max(length(fwidth(p)), 1e-4);
	float h = 0.5;
	vec3 col = color_a;
	float r = rough;
	float sp = spec;
	float a = v_uv2.y;
	float d = min(a, 1.0 - a) * 2.0;
	if (mode == 0) {
		// el pico: de la base a la punta (UV.x en mm), más oscuro hacia la punta, con líneas de crecimiento
		float t = clamp(p.x / len_mm, 0.0, 1.0);
		col = mix(color_a, color_b, smoothstep(tip_from, 1.0, t));
		float lines = 0.5 + 0.5 * sin(p.x * 3.1 + sin(p.y * 0.8) * 0.6);
		h = mix(0.5, lines, (1.0 - smoothstep(0.2, 0.6, px / 1.0)) * 0.5);
		col *= 0.95 + 0.08 * lines;
		r = rough * (0.8 + 0.4 * t);
	} else if (mode == 1) {
		float n = hash12(floor(p / 0.35));
		h = mix(0.5, n, (1.0 - smoothstep(0.2, 0.5, px / 0.35)) * detail);
		col = mix(color_a, color_b, 0.25 * n);
	} else if (mode == 2) {
		// escamas: más grandes en el lomo (d → 0) que en la tripa
		float size = scale_mm * mix(1.35, 0.7, smoothstep(0.2, 0.9, d));
		vec3 vr = voronoi(p / size);
		float edge = smoothstep(0.0, 0.18, vr.y - vr.x);
		float dome = 1.0 - vr.x * vr.x;
		float kk = (1.0 - smoothstep(0.25, 0.7, px / size)) * detail;
		h = mix(0.5, edge * (0.55 + 0.45 * dome), kk);
		col = mix(color_b, color_a, mix(0.75, edge * (0.7 + 0.3 * vr.z), kk));
		col = mix(col, color_a * 1.15, smoothstep(0.55, 0.95, d) * 0.6);
		if (stripes > 0.5) {
			float s = v_uv2.x;
			float ph = s * stripe_n + 0.35 * sin(s * 23.0 + d * 4.0);
			float st = 1.0 - smoothstep(0.12, 0.2, abs(fract(ph) - 0.5));
			st *= (1.0 - smoothstep(0.35, 0.6, d)) * step(0.12, s);
			col = mix(col, stripe_color, st * 0.85);
		}
		r = mix(rough, 0.8, 1.0 - edge);
	} else if (mode == 3) {
		vec3 vr = voronoi(p / 0.8);
		float kk = (1.0 - smoothstep(0.25, 0.7, px / 0.8)) * detail;
		h = mix(0.5, smoothstep(0.0, 0.2, vr.y - vr.x), kk);
		col = mix(color_b, color_a, mix(0.8, 0.6 + 0.4 * h, kk));
		// húmeda, pero con su empedrado: más mate en los surcos
		r = mix(rough, 0.75, (1.0 - h) * kk);
		sp = spec;
	} else if (mode == 4) {
		vec3 vr = voronoi(p / 0.55);
		float kk = (1.0 - smoothstep(0.25, 0.7, px / 0.55)) * detail;
		float pap = 1.0 - smoothstep(0.05, 0.4, vr.x);
		h = mix(0.5, pap, kk);
		col = mix(color_a, color_b, 0.3 * pap * kk + 0.25 * smoothstep(0.3, 0.0, abs(a - 0.5)));
		r = 0.22;
		sp = 0.7;
	} else if (mode == 5) {
		float n = hash12(floor(p / 0.5));
		h = mix(0.5, n, (1.0 - smoothstep(0.2, 0.5, px / 0.5)) * 0.4 * detail);
		col = mix(color_a, color_b, 0.3 * n);
		r = 0.35;
	} else {
		// el párpado: la piel y el borde oscuro
		float rim = 1.0 - smoothstep(rim_mm * 0.6, rim_mm, p.x);
		col = mix(color_a, color_b, rim);
		h = 0.5 + 0.2 * hash12(floor(p / 0.4));
		r = mix(rough, 0.3, rim);
	}
	ALBEDO = col * (0.35 + 0.65 * v_col.r);
	ROUGHNESS = r;
	SPECULAR = sp;
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
