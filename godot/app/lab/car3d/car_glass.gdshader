// Lunas del turismo del coche en marcha (unidad 4k): vidrio de verdad, transparente y tintado, con el reflejo de Fresnel
// (más espejo cuanto más de canto se mira: F = F0 + (1 − F0)·(1 − cos θ)⁵, F0 = 0,04 del vidrio) y, detrás, el interior
// oscuro. Parabrisas y ventanillas de delante dejan pasar ~el 72 % de la luz (el mínimo legal es el 70 %); las de atrás y la
// luneta, tintadas de fábrica («privacy glass»), menos (dibujo).
// Daños (car3d/car_damage.gd, con los datos de impact() y hold_report() a través del estado):
//   - parabrisas laminado: grietas en estrella (radiales) y en telaraña (anillos) alrededor del golpe y el centro
//     machacado; el PVB lo sujeta: no cae (Glazing.laminated_result);
//   - ventanilla templada que estalla: se cuartea en trocitos romos del tamaño de Glazing.fragment_size_mm (~5,6 mm con
//     100 MPa de compresión) y caen, salvo los que se quedan en el marco;
//   - rayas de unas garras reforjadas más duras que el vidrio (los surcos de car_damage.gdshaderinc).
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://app/lab/car3d/car_damage.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.09, 0.12, 0.125);
uniform float transmit = 0.72;
uniform float transmit_rear = 0.4;
uniform float rear_x = 2.23;
uniform float luneta_x = 1.46;
// Grietas del laminado: centro (objeto) y radio (m); (semilla, radiales, golpe, tipo: 0 golpe, 1 bajo una pata).
const int MAX_CRACKS = 6;
uniform int n_cracks = 0;
uniform vec4 crack_c[MAX_CRACKS];
uniform vec4 crack_p[MAX_CRACKS];
uniform vec3 crack_e1 = vec3(-0.814, 0.581, 0.0);
// Templado: lo que ha estallado cada ventanilla (0 entera · hasta 0,35 se cuartea · luego caen los trozos · 1 caída) y el
// tamaño de los trozos (m). Contornos de las dos ventanillas (x, y) para dejar los trozos del marco.
uniform float shatter_front = 0.0;
uniform float shatter_rear = 0.0;
uniform float frag_m = 0.0056;
const int WIN_PTS = 12;
uniform vec2 win_front[WIN_PTS];
uniform vec2 win_rear[WIN_PTS];
// Luz del sol (unidad 4w): el destello del disco del sol en el vidrio, donde su reflejo especular cae hacia quien mira
// (car_scene.gd: sun_glint 0 con la luz de siempre, que sale tal cual). Dirección hacia el sol, en el mundo.
uniform vec3 sun_glint_dir = vec3(0.42, 0.8, 0.45);
uniform vec3 sun_glint_color : source_color = vec3(1.0, 0.95, 0.88);
uniform float sun_glint = 0.0;
// Unidad 4v: la luneta templada que estalla bajo el animal (0 entera · hasta 0,35 se cuartea · luego caen los trozos · 1
// caída) y su panel (x de abajo y de arriba, m del objeto): los trozos del marco se quedan.
uniform float shatter_luneta = 0.0;
uniform vec2 luneta_span = vec2(0.63, 1.44);

varying vec3 v_obj;
varying vec3 v_objn;

void vertex() {
	v_obj = VERTEX;
	v_objn = NORMAL;
}

vec2 g_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Líneas de las grietas del laminado en l (m, en el plano del parabrisas, desde el centro del golpe): radiales de largo
// distinto y anillos de telaraña entre radiales vecinas. Devuelve la cobertura (0-1).
float laminated(vec2 l, float big, float seed, float radials, float px) {
	float r = length(l);
	if (r > big * 1.05) {
		return 0.0;
	}
	float ang = atan(l.y, l.x) + 3.14159265;
	float k = floor(ang / 6.2831853 * radials);
	float best = 1e9;
	float th0 = 0.0;
	float th1 = 0.0;
	float len0 = big;
	float len1 = big;
	for (int j = -1; j <= 1; j++) {
		float kk = k + float(j);
		float kj = mod(kk + radials, radials);
		float th = (kk + 0.5 + (dmg_hash(kj + seed) - 0.5) * 0.7) / radials * 6.2831853 - 3.14159265;
		float len = big * (0.5 + 0.5 * dmg_hash(kj * 3.1 + seed * 1.7));
		vec2 dir = vec2(cos(th), sin(th));
		float t = clamp(dot(l, dir), 0.0, len);
		// la grieta no es recta: se quiebra un poco
		vec2 wob = vec2(-dir.y, dir.x) * sin(t / big * 9.0 + kj) * big * 0.018;
		best = min(best, length(l - dir * t - wob));
		if (j == 0) {
			th0 = th;
			len0 = len;
		} else if (j == 1) {
			th1 = th;
			len1 = len;
		}
	}
	// telaraña: anillos poligonales entre la radial k y la k+1 (en el sector en que está l)
	for (int j = 0; j < 4; j++) {
		float rho = big * (0.12 + 0.19 * float(j)) * (1.0 + (dmg_hash(k * 7.0 + float(j) + seed) - 0.5) * 0.25);
		if (rho > min(len0, len1)) {
			continue;
		}
		vec2 a = vec2(cos(th0), sin(th0)) * rho;
		vec2 b = vec2(cos(th1), sin(th1)) * rho * (1.0 + (dmg_hash(k * 5.0 + float(j) * 2.0 + seed) - 0.5) * 0.2);
		best = min(best, dmg_seg(l, a, b));
	}
	float w = max(big * 0.002, px * 0.5);
	float cov = 1.0 - smoothstep(w - px * 0.5, w + px * 0.5, best);
	// el centro machacado: vidrio blanco, sujeto por la lámina
	cov = max(cov, (1.0 - smoothstep(big * 0.05, big * 0.08, r)) * 0.85);
	return cov;
}

// Unidad 4v: el cuarteado del templado en q (m, en su plano) con trozos de frag_m; s: lo que ha estallado; frame: lo que dista
// del marco (los trozos junto a él se quedan). Devuelve el blanco del cuarteado, o -1 si el trozo ya ha caído.
float tempered_craze(vec2 q0, float s, float frame, float px) {
	vec2 q = q0 / frag_m;
	vec2 g = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 cid = g;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 rr = o + g_hash2(g + o) - f;
			float d = dot(rr, rr);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				cid = g + o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float h = g_hash2(cid * 1.37).x;
	float fall = clamp((s - 0.35) / 0.65, 0.0, 1.0);
	bool keep = frame < 0.012 + 0.03 * g_hash2(cid * 2.1).y;
	if (!keep && h < fall) {
		return -1.0;
	}
	float pc = px / frag_m;
	float edge = sqrt(d2) - sqrt(d1);
	float line = 1.0 - smoothstep(0.0, max(pc, 0.06), edge);
	return mix(line, 0.55, smoothstep(0.35, 1.0, pc)) * clamp(s / 0.35, 0.0, 1.0);
}

// Distancia de p al contorno de una ventanilla.
float win_edge(vec2 p, bool front) {
	float best = 1e9;
	for (int i = 0; i < WIN_PTS; i++) {
		int j = (i + 1) % WIN_PTS;
		best = min(best, front ? dmg_seg(p, win_front[i], win_front[j]) : dmg_seg(p, win_rear[i], win_rear[j]));
	}
	return best;
}

void fragment() {
	vec3 n = normalize(v_objn);
	float px = max(length(fwidth(v_obj)) * 0.7, 1e-5);
	bool side = abs(n.z) > 0.5;
	bool rear = side ? v_obj.x < rear_x : (v_obj.x < luneta_x);
	float tr = rear ? transmit_rear : transmit;
	float cos_v = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - cos_v, 5.0);
	float alpha = 1.0 - tr * (1.0 - fres);
	vec3 col = tint;
	float rough = 0.03;
	float white = 0.0;
	// ventanilla templada que estalla
	if (side) {
		float s = v_obj.x >= rear_x ? shatter_front : shatter_rear;
		if (s > 0.001) {
			vec2 q = v_obj.xy / frag_m;
			vec2 g = floor(q);
			vec2 f = fract(q);
			float d1 = 8.0;
			float d2 = 8.0;
			vec2 cid = g;
			for (int j = -1; j <= 1; j++) {
				for (int i = -1; i <= 1; i++) {
					vec2 o = vec2(float(i), float(j));
					vec2 rr = o + g_hash2(g + o) - f;
					float d = dot(rr, rr);
					if (d < d1) {
						d2 = d1;
						d1 = d;
						cid = g + o;
					} else if (d < d2) {
						d2 = d;
					}
				}
			}
			float h = g_hash2(cid * 1.37).x;
			float fall = clamp((s - 0.35) / 0.65, 0.0, 1.0);
			float frame = win_edge(v_obj.xy, v_obj.x >= rear_x);
			bool keep = frame < 0.012 + 0.03 * g_hash2(cid * 2.1).y;
			if (!keep && h < fall) {
				discard;
			}
			float pc = px / frag_m;
			float edge = sqrt(d2) - sqrt(d1);
			float line = 1.0 - smoothstep(0.0, max(pc, 0.06), edge);
			// más fino que un píxel: el cuarteado se ve lechoso
			float craze = mix(line, 0.55, smoothstep(0.35, 1.0, pc)) * clamp(s / 0.35, 0.0, 1.0);
			white = max(white, craze);
		}
	}
	// unidad 4v: la luneta templada que estalla bajo el animal
	if (!side && v_obj.x < luneta_x && shatter_luneta > 0.001) {
		float lf = min(v_obj.x - luneta_span.x, luneta_span.y - v_obj.x);
		float lc = tempered_craze(v_obj.xz, shatter_luneta, lf, px);
		if (lc < 0.0) {
			discard;
		}
		white = max(white, lc);
	}
	// grietas del parabrisas laminado
	if (!side) {
		for (int i = 0; i < MAX_CRACKS; i++) {
			if (i >= n_cracks) {
				break;
			}
			vec4 cc = crack_c[i];
			vec4 cp = crack_p[i];
			float prog = dmg_progress_crush(cp.z);
			if (prog <= 0.0) {
				continue;
			}
			vec3 dp = v_obj - cc.xyz;
			vec2 l = vec2(dot(dp, crack_e1), dp.z);
			white = max(white, laminated(l, cc.w * prog, cp.x, cp.y, px));
		}
	}
	// rayas de unas garras más duras que el vidrio
	vec4 m = damage_marks(v_obj, n, px);
	white = max(white, m.x * 0.8);
	white = max(white, dmg_glass_chips(v_obj, n, px) * 0.55);  // unidad 4y: el microastillado a los lados de la raya
	if (white > 0.0) {
		col = mix(col, vec3(0.82, 0.86, 0.88), white);
		alpha = mix(alpha, 0.92, white);
		rough = mix(rough, 0.5, white);
	}
	// el destello del sol (unidad 4w)
	if (sun_glint > 0.0) {
		vec3 lv = normalize((VIEW_MATRIX * vec4(sun_glint_dir, 0.0)).xyz);
		float g = max(dot(reflect(-VIEW, NORMAL), lv), 0.0);
		float glint = sun_glint * (pow(g, 500.0) * 4.0 + pow(g, 40.0) * 0.3);
		EMISSION = sun_glint_color * glint;
		alpha = max(alpha, min(glint, 1.0));
	}
	ALBEDO = col * alpha;
	ALPHA = alpha;
	METALLIC = 0.0;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
}
