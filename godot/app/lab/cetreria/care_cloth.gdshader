// Cetrería · la tela (unidad 5h; dibujo hecho en código): la toalla de rizo con sus franjas (la que envuelve a la rapaz y
// la de debajo) y el paño verde de quirófano de la clínica. El rizo: bucles diminutos que rompen la luz (un relieve de
// puntos y su sombra); el paño, un tejido de tafetán fino. UV en metros por la malla (las de la escena) × uv_scale. El
// color del vértice (si lo hay) trae la sombra de los pliegues.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.87, 0.9, 0.93);
uniform vec3 stripe_color : source_color = vec3(0.5, 0.65, 0.8);
uniform float stripe_m = 0.06;       // separación de las franjas (m)
uniform float stripe_w = 0.18;       // ancho de cada franja (fracción)
uniform float terry = 1.0;           // 1: rizo de toalla; 0: tejido liso de paño
uniform float loop_mm = 1.6;         // tamaño de los bucles del rizo
uniform float uv_scale = 1.0;        // metros por unidad de UV
uniform float use_vertex_ao = 0.0;   // la malla trae la sombra de los pliegues en el color del vértice

varying vec2 v_m;
varying float v_ao;

void vertex() {
	v_m = UV * uv_scale;
	v_ao = mix(1.0, COLOR.r, use_vertex_ao);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 mm = v_m * 1000.0;
	float px = max(length(fwidth(mm)), 1e-3);
	// las franjas, a lo largo de v
	float fs = fract(v_m.y / stripe_m);
	float stripe = smoothstep(0.0, 0.02, fs) * (1.0 - smoothstep(stripe_w, stripe_w + 0.02, fs));
	vec3 col = mix(base_color, stripe_color, stripe);
	float h = 0.5;
	if (terry > 0.5) {
		// el rizo: cada bucle, un punto con su sombra
		vec2 c = mm / loop_mm;
		vec2 f = fract(c) - 0.5;
		float rnd = hash12(floor(c));
		float loop_h = 1.0 - smoothstep(0.1, 0.5, length(f + (rnd - 0.5) * 0.3));
		float k = smoothstep(0.6, 0.15, px / loop_mm);
		h = mix(0.5, loop_h, k);
		col *= mix(1.0, 0.82 + 0.3 * loop_h, k);
	} else {
		// tafetán: hilos que se cruzan
		vec2 w = mm / 0.45;
		float warp = 0.5 + 0.5 * sin(w.x * 6.2832);
		float weft = 0.5 + 0.5 * sin(w.y * 6.2832);
		float k = smoothstep(0.6, 0.15, px / 0.45);
		h = mix(0.5, max(warp, weft), k);
		col *= mix(1.0, 0.9 + 0.12 * h, k);
	}
	ALBEDO = col * (0.45 + 0.55 * v_ao);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	float hm = (h - 0.5) * (terry > 0.5 ? 0.6 : 0.15) * 0.001;
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
