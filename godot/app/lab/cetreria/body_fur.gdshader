// Cetrería · el pelo de los cuerpos en alta definición (unidad 5i, petición 37; dibujo hecho en código): la piel bajo el pelo
// (la pasada base, opaca) y las capas del pelo (la técnica de las conchas: un MultiMesh con la misma malla repetida; cada
// instancia lleva su altura en INSTANCE_CUSTOM.r). Para que se vea pelo con volumen y no púas sueltas:
//   - los pelos se juntan en mechones (celdas de Voronoi de clump_mm): hacia la punta, los pelos de cada mechón se acercan
//     a su centro y el mechón acaba en punta; entre mechones queda un hueco que deja ver el pelo de debajo;
//   - el pelo se peina a lo largo del cuerpo (TANGENT: hacia la cola y hacia las manos) y cae por su peso;
//   - de lejos (el pelo mide menos de un píxel) las capas se rellenan: el pelo se ve como una masa con volumen.
// El color: de la raíz a la punta, más claro en la tripa (UV2.y: la vuelta, 0 el lomo y 0,5 la tripa), con las rayas del
// tigre (pattern 1: el cuerpo, por UV2.x, dónde está en el cuerpo; 2: la cabeza, por la posición en su marco y la del
// ojo; 3: la oreja), el hocico claro del oso (4), las bandas del velocirraptor reconstruido (5) y las puntas canosas del
// oso (grizzle). Donde no hay pelo (COLOR.b ~ 0), las capas no se dibujan. COLOR = (oclusión, zona, largo del pelo, cuánto respira); la zona dice
// si es el tronco (0), una pata (0,25), la cola (0,5) o la cabeza y el cuello (0,75).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool shell = false;
uniform vec3 root_color : source_color = vec3(0.43, 0.23, 0.07);
uniform vec3 tip_color : source_color = vec3(0.85, 0.54, 0.23);
uniform vec3 belly_color : source_color = vec3(0.94, 0.88, 0.76);
uniform vec3 dark_color : source_color = vec3(0.035, 0.028, 0.025);
uniform float belly = 0.0;
uniform float fur_mm = 12.0;
uniform float strand_mm = 0.32;
uniform float clump_mm = 2.6;
uniform float clump = 0.55;
uniform float thick = 0.85;
uniform float comb = 0.7;
uniform float droop = 0.15;
uniform float grizzle = 0.0;
uniform float tone_var = 0.12;
uniform int pattern = 0;
uniform vec3 head_half = vec3(0.2, 0.13, 0.13);
uniform vec3 eye_at = vec3(0.24, 0.42, 0.45);
uniform vec3 face_at = vec3(0.3, -0.45, 0.25);
uniform float stripe_n = 40.0;
uniform float tail_from = 0.69;
uniform float breath = 0.0;
uniform float breath_mm = 6.0;
uniform float rough = 0.78;
uniform float spec = 0.32;

varying vec2 v_uv;
varying vec2 v_uv2;
varying vec4 v_col;
varying float v_h;
varying vec3 v_obj;

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

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float h = shell ? INSTANCE_CUSTOM.r : 0.0;
	v_h = h;
	v_uv = UV;
	v_uv2 = UV2;
	v_col = COLOR;
	v_obj = VERTEX;
	vec3 n = NORMAL;
	vec3 fl = TANGENT - n * dot(TANGENT, n);
	fl = length(fl) > 1e-5 ? normalize(fl) : vec3(0.0);
	float len = fur_mm * 0.001 * COLOR.b;
	VERTEX += n * (breath * COLOR.a * breath_mm * 0.001);
	VERTEX += n * (h * len * (1.0 - 0.45 * comb * h)) + fl * (h * h * comb * len) + vec3(0.0, -1.0, 0.0) * (h * h * droop * len);
}

// Las rayas del cuerpo del tigre: bandas de través (del lomo hacia la tripa) que se afilan y acaban a distintas alturas,
// algunas se parten en dos; en la cola, anillos y la punta negra. s: dónde está en el cuerpo (0 morro, 1 punta de la
// cola); d: 0 el lomo → 1 la tripa; side: el costado.
float tiger_body(float s, float d, float side) {
	float p = s * stripe_n + 0.3 * sin(s * 29.0 + d * 3.1) + d * (0.45 + 0.25 * sin(s * 9.0));
	float i = floor(p);
	float f = fract(p) - 0.5;
	float seed = i * 1.37 + side * 57.0;
	// hasta dónde baja cada raya (0 el lomo, 1 la tripa) y su ancho; alguna se parte en dos
	float L = mix(0.5, 0.82, hash12(vec2(seed, 1.0)));
	float w = mix(0.13, 0.27, hash12(vec2(seed, 2.0)));
	float fork = step(0.78, hash12(vec2(seed, 3.0)));
	float fd = max(d - L * 0.5, 0.0);
	f = mix(f, abs(f) - fd * 0.38, fork);
	float taper = 1.0 - smoothstep(0.0, L, d);
	float hw = w * pow(max(taper, 0.0), 0.5) * (1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.15, d)));
	hw += (vnoise(vec2(s * 160.0, d * 9.0)) - 0.5) * 0.035;
	float m = 1.0 - smoothstep(hw * 0.8, hw, abs(f));
	m *= 1.0 - smoothstep(0.78, 0.9, d);
	// la cola: anillos completos que se ensanchan, y la punta negra
	float tail = smoothstep(tail_from - 0.01, tail_from + 0.03, s);
	float pt = s * stripe_n * 0.62 + 0.25 * sin(d * 6.2832);
	float ring = 1.0 - smoothstep(0.17, 0.24, abs(fract(pt) - 0.5) - 0.5 * smoothstep(0.86, 0.99, s));
	float tip = smoothstep(0.955, 0.975, s);
	return max(mix(m, ring, tail), tip);
}

// La cara del tigre (en el marco de la cabeza: x hacia el morro, y hacia arriba, z hacia la derecha; normalizado con
// head_half; eye_at, el ojo derecho; face_at, el escalón de la frente (x), el labio en la comisura (y) y la comisura (x)),
// vista sobre todo de lado (el tigre está tumbado), con las marcas que siguen la forma de la cabeza (unidad 5n): el blanco
// de las almohadillas de los bigotes y del labio (el caballete, naranja), de la barbilla y de la garganta, la mancha de
// encima de cada ojo, la media luna de debajo y la gorguera de los carrillos; el negro del borde del ojo, la raya que sale
// del rabillo hacia la oreja, las tres rayas gruesas de la gorguera (paralelas a la mandíbula, de debajo del ojo hacia
// atrás), las barras rotas de la frente (de través, como las del cuello, partidas en medio), las rayas de la nuca y las
// filas de puntos de los bigotes. El resto, naranja. → (blanco, negro)
vec2 tiger_head(vec3 q) {
	float az = abs(q.z);
	float ex = q.x - eye_at.x;
	float ey = q.y - eye_at.y;
	float sx = face_at.x;
	float ly = face_at.y;
	float cx = face_at.z;
	// en el costado de la cara (más allá de la línea de los ojos)
	float lat = smoothstep(eye_at.z - 0.2, eye_at.z + 0.1, az);
	float white = 0.0;
	// las almohadillas de los bigotes y el labio de arriba: delante del escalón, los lados del hocico (el caballete, naranja)
	float muzzle = smoothstep(sx - 0.02, sx + 0.14, q.x);
	white = max(white, muzzle * (1.0 - smoothstep(0.12, 0.3, q.y + 0.35 * (0.4 - az))));
	// la barbilla y el labio de abajo, bajo la línea de la boca; la garganta, abajo del todo
	white = max(white, (1.0 - smoothstep(ly - 0.14, ly - 0.03, q.y)) * smoothstep(cx - 0.4, cx - 0.12, q.x));
	white = max(white, 1.0 - smoothstep(-0.78, -0.6, q.y));
	// la mancha de encima del ojo, hacia la frente
	white = max(white, (1.0 - smoothstep(0.75, 1.0, length(vec2((ex + 0.02) / 0.12, (ey - 0.25) / 0.085)))) * smoothstep(eye_at.z - 0.3, eye_at.z - 0.12, az));
	// la media luna de debajo del ojo, que baja hacia el carrillo
	white = max(white, (1.0 - smoothstep(0.7, 1.0, length(vec2((ex + 0.0) / 0.17, (ey + 0.19) / 0.1)))) * lat);
	// la gorguera: los carrillos blancos detrás de la comisura y por debajo del ojo
	float ruff = smoothstep(cx + 0.06, cx - 0.1, q.x) * (1.0 - smoothstep(-0.36, -0.22, ey)) * smoothstep(-0.95, -0.7, q.x) * smoothstep(0.5, 0.75, az);
	white = max(white, ruff);
	float black = 0.0;
	// el borde del ojo: una línea negra fina junto a lo que se ve del ojo (hundido, asoma algo más de medio radio)
	float de = length(vec2(ex / 0.065, ey / 0.1));
	black = max(black, (1.0 - smoothstep(1.05, 1.32, de)) * smoothstep(0.8, 0.95, de) * smoothstep(eye_at.z - 0.2, eye_at.z, az));
	// la raya del rabillo del ojo, hacia atrás y hacia arriba, cada vez más fina
	vec2 a0 = vec2(-0.1, 0.02);
	vec2 a1 = vec2(-0.55, 0.24);
	vec2 pe = vec2(ex, ey);
	float t = clamp(dot(pe - a0, a1 - a0) / dot(a1 - a0, a1 - a0), 0.0, 1.0);
	float dl = length(pe - mix(a0, a1, t)) / mix(0.05, 0.02, t);
	black = max(black, lat * (1.0 - smoothstep(0.75, 1.0, dl)));
	// las tres rayas de la gorguera: gruesas, paralelas a la mandíbula, de debajo del ojo hacia atrás y hacia abajo
	float cs = ey + 0.55 * (ex + 0.08);
	float band = 0.0;
	for (int i = 0; i < 3; i++) {
		float c = -0.3 - 0.17 * float(i) + 0.025 * sin(ex * 8.0 + float(i) * 1.7);
		float w = (0.05 - 0.008 * float(i)) * (0.6 + 0.4 * smoothstep(-0.9, -0.3, ex));
		band = max(band, 1.0 - smoothstep(w * 0.7, w, abs(cs - c)));
	}
	band *= lat * smoothstep(0.0, -0.14, ex) * smoothstep(-1.0, -0.78, q.x) * (1.0 - smoothstep(-0.12, 0.02, ey));
	black = max(black, band);
	// la frente: barras de través (como las del cuello), rotas y partidas en medio, entre los ojos y por encima
	float fh = smoothstep(eye_at.y + 0.22, eye_at.y + 0.34, q.y) * (1.0 - smoothstep(eye_at.x + 0.02, eye_at.x + 0.12, q.x)) * smoothstep(eye_at.x - 0.62, eye_at.x - 0.45, q.x);
	float fv = (q.x - eye_at.x) * 6.0 + az * az * 2.6;
	float fm = (1.0 - smoothstep(0.08, 0.13, abs(fract(fv) - 0.5))) * step(0.35, vnoise(vec2(q.x * 6.0, az * 9.0))) * smoothstep(0.035, 0.07, az);
	black = max(black, fh * fm * (1.0 - smoothstep(eye_at.z - 0.05, eye_at.z + 0.1, az)));
	// la nuca y lo alto de la cabeza, detrás de las orejas: rayas de través como las del cuello
	float nape = 1.0 - smoothstep(eye_at.x - 0.85, eye_at.x - 0.6, q.x);
	float nst = abs(fract(q.x * 3.4 + az * 0.9 + 0.15 * sin(q.y * 5.0)) - 0.5);
	black = max(black, nape * step(-0.2, q.y) * (1.0 - smoothstep(0.08, 0.13, nst)));
	// las filas de puntos de los bigotes, sobre el blanco de las almohadillas
	vec2 g = vec2((q.x - sx - 0.18) * 22.0, (q.y - ly - 0.06) * 26.0);
	float row = floor(g.y);
	g.x += 0.5 * mod(row, 2.0);
	vec2 cell = floor(g);
	vec2 o = (hash22(cell) - 0.5) * 0.3;
	float dots = (1.0 - smoothstep(0.15, 0.23, length(fract(g) - 0.5 - o))) * step(0.0, row) * step(row, 4.0)
		* step(0.0, g.x) * step(g.x, 7.0) * smoothstep(0.22, 0.32, az) * step(0.25, hash12(cell + 7.0));
	black = max(black, dots * 0.9);
	// sin rayas en el caballete ni en el blanco de la barbilla
	black *= 1.0 - muzzle * (1.0 - smoothstep(0.18, 0.28, az)) * step(0.0, q.y);
	black *= 1.0 - (1.0 - smoothstep(ly - 0.2, ly - 0.06, q.y)) * smoothstep(cx - 0.2, cx, q.x);
	return vec2(white, black);
}

void fragment() {
	float h = v_h;
	// el mechón: la celda de Voronoi más cercana (estirada a lo largo del pelo)
	vec2 cs = vec2(clump_mm * 1.7, clump_mm);
	vec2 cp = v_uv / cs;
	vec2 ci = floor(cp);
	vec2 cf = fract(cp);
	float dmin = 9.0;
	vec2 cc = vec2(0.0);
	float cid = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.15 + 0.7 * hash22(ci + g);
			vec2 dd = g + o - cf;
			float q = dot(dd, dd);
			if (q < dmin) {
				dmin = q;
				cc = dd;
				cid = hash12(ci + g + 3.7);
			}
		}
	}
	// los pelos del mechón se acercan a su centro hacia la punta
	vec2 sp = v_uv / strand_mm + cc * cs / strand_mm * clump * h;
	vec2 si = floor(sp);
	vec2 sf = fract(sp) - 0.5;
	float r1 = hash12(si);
	float r2 = hash12(si + 17.0);
	vec2 off = (vec2(r1, r2) - 0.5) * 0.55;
	float own = (0.62 + 0.38 * r2) * mix(1.0, 0.7 + 0.6 * cid, 0.55);
	float rr = 0.5 * thick * (1.0 - h / own);
	// el borde del mechón: más corto lejos de su centro (acaba en punta)
	own *= 1.0 - 0.35 * smoothstep(0.15, 0.6, sqrt(dmin));
	float px = max(length(fwidth(v_uv)), 1e-4) / strand_mm;
	float fill = smoothstep(0.55, 1.6, px);
	rr = mix(rr, 0.75 * (1.0 - h / own), fill);
	// sin pelo (el hocico del velocirraptor, alrededor de los ojos y de la trufa): las capas no se dibujan
	if (h > 0.001 && (length(sf - off) > rr || h > own || v_col.b < 0.02)) {
		discard;
	}
	float a = v_uv2.y;
	float d = min(a, 1.0 - a) * 2.0;
	float zone = v_col.g;
	vec3 col = mix(root_color, tip_color, clamp(smoothstep(0.0, 1.0, h / max(own, 0.05)) * 0.8 + 0.2, 0.0, 1.0));
	col *= 1.0 - tone_var * 0.5 + tone_var * (0.6 * cid + 0.4 * r1);
	col = mix(col, belly_color, belly * smoothstep(0.72, 0.9, d));
	if (pattern == 1) {
		float side = a < 0.5 ? 0.0 : 1.0;
		float st = 0.0;
		if (zone > 0.15 && zone < 0.4) {
			// las patas: bandas de través por el largo (UV.x, mm), solo por fuera
			float b = abs(fract(v_uv.x / 95.0 + 0.2 * sin(v_uv.y * 0.02)) - 0.5);
			st = (1.0 - smoothstep(0.08, 0.14, b)) * (1.0 - smoothstep(0.35, 0.6, d));
		} else {
			st = tiger_body(v_uv2.x, d, side);
		}
		col = mix(col, dark_color, st);
	} else if (pattern == 2) {
		vec2 wb = tiger_head(v_obj / head_half);
		col = mix(col, belly_color, wb.x);
		col = mix(col, dark_color, wb.y);
	} else if (pattern == 4) {
		// el hocico del oso, más claro (belly_color, en la cabeza del oso)
		vec3 q = v_obj / head_half;
		col = mix(col, belly_color * (0.85 + 0.3 * r1), smoothstep(0.2, 0.62, q.x) * 0.72);
	} else if (pattern == 5) {
		// el velocirraptor reconstruido: el lomo con bandas de través difusas que se marcan más en la cola
		float sb = v_uv2.x;
		float bars = smoothstep(0.3, 0.7, 0.5 + 0.5 * sin(sb * stripe_n * 6.2832 + d * 1.6 + 0.4 * sin(sb * 41.0))) * (1.0 - smoothstep(0.3, 0.62, d));
		bars *= mix(0.4, 1.0, smoothstep(tail_from, tail_from + 0.12, sb));
		col = mix(col, dark_color, bars * 0.6);
	} else if (pattern == 3) {
		// la oreja: negra por detrás con la mancha blanca en medio; blanca y peluda por dentro (UV2.y: 0 detrás, 0,5 dentro)
		float back = 1.0 - smoothstep(0.2, 0.32, d);
		float spot = 1.0 - smoothstep(0.1, 0.16, length(vec2((v_uv2.x - 0.55) * 1.4, min(a, 1.0 - a) * 2.0)));
		col = mix(col, dark_color, back);
		col = mix(col, belly_color, back * spot);
		col = mix(col, belly_color, smoothstep(0.55, 0.8, d));
	}
	col = mix(col, belly_color * 1.05, grizzle * smoothstep(0.55, 1.0, h / max(own, 0.05)) * (0.4 + 0.6 * r1));
	float self_shadow = mix(0.42, 1.0, smoothstep(0.0, 0.9, h));
	ALBEDO = col * self_shadow * (0.32 + 0.68 * v_col.r);
	ROUGHNESS = rough;
	SPECULAR = spec * (0.6 + 0.4 * h);
}
