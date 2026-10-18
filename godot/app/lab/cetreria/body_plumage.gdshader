// Cetrería · el plumaje pequeño de las aves y de la reconstrucción del velocirraptor (unidad 5i, petición 37; dibujo hecho
// en código): las plumas de contorno que se montan unas sobre otras como tejas, cada una con su punta redonda, su raquis y
// sus barbas, y el relieve de la punta (un mapa de normales hecho en código, de las derivadas en pantalla como en
// paw_skin.gdshader). Es la superficie bajo las plumas de tarjeta (body_feather.gdshader) y, en el teléfono, lo que se ve.
// UV en mm (body_kit.gd: UV.x a lo largo, hacia donde apunta la pluma; UV.y alrededor) · UV2 = (dónde está en el cuerpo,
// la vuelta: 0 el lomo, 0,5 la tripa) · COLOR = (oclusión, zona, —, cuánto respira).
// mode 0: el cuerpo, con el color de cada zona (el lomo, la tripa, la cabeza y la cola, por UV2); mode 1: la cabeza, con
// el dibujo de la cara de cada especie (face) por la posición en el marco de la cabeza (x hacia el pico, y hacia arriba,
// z hacia la derecha; normalizada con head_half).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;
uniform int face = 0;
uniform vec3 back_color : source_color = vec3(0.24, 0.16, 0.09);
uniform vec3 belly_color : source_color = vec3(0.3, 0.2, 0.12);
uniform vec3 head_color : source_color = vec3(0.6, 0.42, 0.18);
uniform vec3 tail_color : source_color = vec3(0.28, 0.22, 0.17);
uniform vec3 mark_color : source_color = vec3(0.06, 0.05, 0.04);
uniform vec3 pale_color : source_color = vec3(0.92, 0.9, 0.86);
uniform float s_head = 0.22;
uniform float s_tail = 0.62;
uniform float belly_from = 0.62;
uniform int body_pattern = 0;      // 0 liso · 1 barras (halcón) · 2 rayas (búho) · 3 motas (lechuza) · 4 bordes claros
uniform float feather_mm = 9.0;
uniform float relief_mm = 0.5;
uniform float fluffy = 0.0;        // 1: plumón (sin raquis ni puntas limpias: la cabeza del buitre)
uniform vec3 head_half = vec3(0.07, 0.05, 0.05);
uniform float breath = 0.0;
uniform float breath_mm = 4.0;
uniform float detail = 1.0;

varying vec2 v_uv;
varying vec2 v_uv2;
varying vec4 v_col;
varying vec3 v_obj;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_uv = UV;
	v_uv2 = UV2;
	v_col = COLOR;
	v_obj = VERTEX;
	VERTEX += NORMAL * (breath * COLOR.a * breath_mm * 0.001);
}

// El dibujo de la cara (q: en el marco de la cabeza, normalizado). → el color.
vec3 face_color(vec3 q, vec3 base) {
	float az = abs(q.z);
	vec3 c = base;
	if (face == 0) {
		// águila real: la nuca y la coronilla doradas, la cara parda
		float nape = smoothstep(0.15, 0.45, q.y + (0.2 - q.x) * 0.6) * (1.0 - smoothstep(0.55, 0.75, q.x));
		c = mix(back_color, head_color, nape);
	} else if (face == 1) {
		// arpía: la cabeza gris clara, la cresta más oscura, la garganta blanquecina
		c = mix(head_color, head_color * 0.62, smoothstep(0.55, 0.85, q.y) * (1.0 - smoothstep(0.1, 0.4, q.x)));
		c = mix(c, pale_color, 1.0 - smoothstep(-0.55, -0.3, q.y));
	} else if (face == 2) {
		// halcón peregrino: la capucha negra con la bigotera que baja del ojo; las mejillas y la garganta blancas
		float hood = smoothstep(-0.05, 0.12, q.y) + (1.0 - smoothstep(-0.25, 0.05, q.x)) * smoothstep(-0.4, -0.2, q.y);
		float malar = (1.0 - smoothstep(0.08, 0.16, abs(q.x - 0.3 + (q.y + 0.1) * 0.25))) * smoothstep(-0.65, -0.45, q.y) * step(0.35, az);
		c = mix(pale_color, mark_color, clamp(hood + malar, 0.0, 1.0));
	} else if (face == 3) {
		// búho real: el disco facial leonado con su borde oscuro; la frente y la coronilla con rayas; la garganta blanca
		float disc_r = length(vec2((q.x - 0.45) * 1.1, q.y * 0.95)) ;
		float disc = (1.0 - smoothstep(0.62, 0.7, disc_r)) * step(0.0, q.x);
		float rim = (1.0 - smoothstep(0.03, 0.08, abs(disc_r - 0.68))) * step(0.15, q.x);
		c = mix(back_color, head_color, disc);
		c = mix(c, mark_color, rim * 0.9);
		c = mix(c, pale_color, (1.0 - smoothstep(0.12, 0.22, length(vec2(q.x - 0.62, q.y + 0.55)))));
	} else if (face == 4) {
		// lechuza: el disco facial blanco en forma de corazón con el borde ocre; la coronilla dorada
		float hx = (q.x - 0.5) * 1.15;
		float hy = q.y * 0.9 + 0.08;
		float heart = length(vec2(hx, hy - abs(q.z) * 0.15));
		float disc = (1.0 - smoothstep(0.6, 0.66, heart)) * step(0.05, q.x);
		float rim = (1.0 - smoothstep(0.02, 0.06, abs(heart - 0.64))) * step(0.1, q.x);
		c = mix(back_color, pale_color, disc);
		c = mix(c, head_color, rim);
	} else if (face == 5) {
		// buitre leonado: plumón blanco en la cabeza y el cuello, con la piel gris azulada debajo
		c = mix(pale_color, head_color, 0.35 + 0.25 * hash12(floor(v_uv * 0.9)));
	}
	return c;
}

void fragment() {
	vec2 p = v_uv;
	float px = max(length(fwidth(p)), 1e-4);
	// la teja: celdas a lo largo (la pluma apunta hacia +UV.x) en filas al tresbolillo
	vec2 cell = vec2(feather_mm, feather_mm * 0.62);
	vec2 g = p / cell;
	float row = floor(g.y);
	g.x += 0.5 * mod(row, 2.0) + 0.3 * (hash12(vec2(row, 3.0)) - 0.5);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float v = f.y - 0.5;
	float rnd = hash12(id);
	// la punta, algo afilada: dentro, la pluma de esta celda; fuera, la de la celda de delante (que la tapa)
	float tip = 0.92 - 2.1 * v * v + 0.08 * (rnd - 0.5);
	float inside = step(f.x, tip);
	float u = f.x / max(tip, 0.1);
	float h = inside * (0.25 + 0.75 * u) * smoothstep(0.0, 0.12, tip - f.x);
	h = mix(h, 0.5 + 0.5 * hash12(floor(p * 1.8)), fluffy);
	float k = (1.0 - smoothstep(0.35, 0.9, px / feather_mm)) * detail;
	// las barbas y el raquis
	float bph = (f.x * cell.x - abs(v) * cell.y * 0.8) / 0.45;
	float barbs = 1.0 - smoothstep(0.0, 0.4, abs(fract(bph) - 0.5) * 2.0 - 0.55);
	float bk = (1.0 - smoothstep(0.3, 0.8, fwidth(bph))) * (1.0 - fluffy);
	float shaft = (1.0 - smoothstep(0.015, 0.035, abs(v))) * inside * (1.0 - fluffy);
	// el color de la zona
	float s = v_uv2.x;
	float a = v_uv2.y;
	float d = min(a, 1.0 - a) * 2.0;
	vec3 base = mix(back_color, belly_color, smoothstep(belly_from - 0.08, belly_from + 0.08, d));
	base = mix(base, tail_color, smoothstep(s_tail - 0.02, s_tail + 0.02, s));
	base = mix(head_color, base, smoothstep(s_head - 0.03, s_head + 0.03, s));
	if (mode == 1) {
		base = face_color(v_obj / head_half, base);
	}
	vec3 col = base * (0.9 + 0.2 * rnd);
	// el dibujo del cuerpo (en la parte de la tripa y los costados)
	float under = smoothstep(belly_from - 0.15, belly_from + 0.05, d);
	if (body_pattern == 1) {
		col = mix(col, mark_color, under * (1.0 - smoothstep(0.06, 0.12, abs(u - 0.72))) * inside * k);
	} else if (body_pattern == 2) {
		col = mix(col, mark_color, under * (1.0 - smoothstep(0.05, 0.1, abs(v))) * step(0.3, u) * inside * k);
	} else if (body_pattern == 3) {
		float r = length(vec2((u - 0.8) * 2.0, v * 2.5));
		col = mix(col, mark_color, (1.0 - smoothstep(0.08, 0.13, r)) * (1.0 - under) * k);
		col = mix(col, pale_color, (1.0 - smoothstep(0.03, 0.06, r)) * (1.0 - under) * k);
	} else if (body_pattern == 4) {
		col = mix(col, pale_color * 0.85, smoothstep(tip - 0.16, tip - 0.03, f.x) * inside * k * 0.6);
	}
	col *= mix(1.0, 0.82 + 0.18 * barbs, bk * k);
	col = mix(col, col * 1.35, shaft * k * 0.5);
	// lo tapado por la pluma de delante, en sombra suave
	col *= mix(1.0, 0.86 + 0.14 * u, inside * k * (1.0 - fluffy));
	ALBEDO = col * (0.35 + 0.65 * v_col.r);
	ROUGHNESS = mix(0.72, 0.5, shaft);
	SPECULAR = 0.3;
	AO = v_col.r;
	AO_LIGHT_AFFECT = 0.35;
	float hm = (mix(0.5, h, k) - 0.5) * relief_mm * 0.001;
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
