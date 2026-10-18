// Cetrería · las plumas de los cuerpos en alta definición (unidad 5i, petición 37; dibujo hecho en código): cada pluma es una
// tarjeta curvada (body_kit.gd → cards) y aquí se dibuja su forma: el raquis de la raíz a la punta (más fino hacia la
// punta y con brillo), las barbas en diagonal hacia la punta (con alguna separación en el borde, como en una pluma de
// verdad), el plumón de la base y el contorno de cada tipo:
//   0 cobertera del cuerpo (ancha, punta redonda) · 1 cobertera del ala · 2 rémige (primaria o secundaria: la barba de
//   fuera estrecha; con param ≥ 1, la escotadura de las primarias de las águilas y los buitres, los «dedos») · 3 timonera
//   de la cola (ancha, casi paralela) · 4 plumón (sin contorno limpio) · 5 pluma de cresta o de la nuca (lanceolada).
// Y su dibujo (CUSTOM0.y): 0 liso · 1 barras de través (param: cuántas) · 2 una raya en medio (las del pecho del búho) ·
// 3 una mancha cerca de la punta (las de la lechuza) · 4 el borde claro · 5 la punta clara con una barra oscura antes (la
// cola) · 6 una punta de flecha oscura (el pecho del halcón).
// COLOR = (el color de la pluma, su sombra) · UV = (de través −1…1, a lo largo 0…1) · UV2 = (semilla, cuánto respira) ·
// CUSTOM0 = (tipo, dibujo, parámetro, largo en mm) · TANGENT = la normal del cuerpo en la raíz (hacia donde respira).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 bar_color : source_color = vec3(0.07, 0.055, 0.045);
uniform vec3 edge_color : source_color = vec3(0.78, 0.64, 0.42);
uniform vec3 down_color : source_color = vec3(0.82, 0.78, 0.72);
uniform vec3 shaft_color : source_color = vec3(0.85, 0.8, 0.7);
uniform float shaft_mix = 0.35;
uniform float barb_mm = 0.5;
uniform float sheen = 0.25;
uniform float breath = 0.0;
uniform float breath_mm = 4.0;
// 5t-B · las plumas que se erizan en la amenaza y el ataque (0-1, lo mueve reaction/anim_bird.gd): cada pluma se separa del
// cuerpo por su punta (más cuanto más larga), con algo de azar por pluma (dibujo).
uniform float ruffle = 0.0;
uniform float ruffle_k = 0.28;

varying vec2 v_uv;
varying vec4 v_col;
varying vec4 v_cu;
varying vec2 v_uv2;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	v_cu = CUSTOM0;
	v_uv2 = UV2;
	VERTEX += TANGENT * (breath * UV2.y * breath_mm * 0.001);
	if (ruffle > 0.0) {
		float along = clamp(UV.y, 0.0, 1.0);
		VERTEX += TANGENT * (ruffle * ruffle_k * along * along * CUSTOM0.w * 0.001 * (0.7 + 0.6 * hash12(vec2(UV2.x, 7.3))));
	}
}

// El medio ancho de la barba (0-1 del medio ancho de la tarjeta) en y, por el lado de x.
float vane(float kind, float y, float x, float param) {
	float k = floor(kind + 0.5);
	if (k < 0.5 || k > 0.5 && k < 1.5) {
		// coberteras: base estrecha, punta redonda (algo más afilada en el ala)
		float base = mix(0.4, 1.0, smoothstep(0.0, 0.22, y));
		float tip_c = k < 0.5 ? 0.52 : 0.58;
		float tip = y > tip_c ? sqrt(max(1.0 - pow((y - tip_c) / (1.0 - tip_c), 2.0 + k), 0.0)) : 1.0;
		return base * tip;
	}
	if (k < 2.5) {
		// rémige: la barba de fuera (x > 0) estrecha; la de dentro ancha y con la escotadura de los «dedos»
		float outer = 0.32 * (1.0 - smoothstep(0.85, 1.0, y) * 0.8);
		float inner = 1.0 * smoothstep(0.0, 0.08, y + 0.02);
		inner *= mix(1.0, 0.42, step(0.5, param) * smoothstep(0.55, 0.7, y));
		float tip = y > 0.86 ? sqrt(max(1.0 - pow((y - 0.86) / 0.14, 2.0), 0.0)) : 1.0;
		return (x > 0.0 ? outer : inner) * tip;
	}
	if (k < 3.5) {
		float tip = y > 0.84 ? sqrt(max(1.0 - pow((y - 0.84) / 0.16, 2.0), 0.0)) : 1.0;
		return mix(0.55, 1.0, smoothstep(0.0, 0.12, y)) * tip;
	}
	if (k < 4.5) {
		return 0.85 * sin(3.1416 * clamp(y, 0.0, 1.0)) + 0.15;
	}
	// lanceolada
	return 0.75 * pow(sin(3.1416 * pow(clamp(y, 0.0, 1.0), 0.75)), 0.8);
}

void fragment() {
	float x = v_uv.x;
	float y = v_uv.y;
	float kind = v_cu.x;
	float pat = floor(v_cu.y + 0.5);
	float par = v_cu.z;
	float len_mm = max(v_cu.w, 1.0);
	float seed = v_uv2.x;
	float k = floor(kind + 0.5);
	float w = vane(kind, y, x, par);
	// las barbas: líneas en diagonal hacia la punta; el borde, hecho de puntas de barba (algunas se separan)
	float aspect = k > 1.5 && k < 2.5 ? 0.16 : (k > 2.5 && k < 3.5 ? 0.24 : (k > 4.5 ? 0.2 : 0.6));
	float bph = (y - abs(x) * aspect * 0.9) * len_mm / barb_mm;
	float bi = floor(bph);
	float edge = abs(x) - w;
	float ragged = (hash12(vec2(bi, seed * 97.0 + sign(x))) - 0.5) * 0.12 + 0.04;
	if (k > 3.5 && k < 4.5) {
		ragged = (hash12(vec2(floor(bph * 0.5), seed * 31.0 + sign(x))) - 0.5) * 0.45;
	}
	// una separación entre barbas de vez en cuando (la «cremallera» abierta)
	float split = step(0.93, hash12(vec2(floor(bph / 9.0), seed * 13.0 + sign(x)))) * step(0.45, abs(x) / max(w, 0.01));
	float split_line = 1.0 - smoothstep(0.0, 0.18, abs(fract(bph / 9.0) - 0.5));
	// el borde, deshilachado: una franja estrecha donde se descarta al azar (se ve blando, no recortado)
	float fuzz = 0.08 * (1.0 + step(3.5, k) * 2.0);
	float dither = hash12(floor(FRAGCOORD.xy) + vec2(seed * 131.0, 7.0));
	if (edge > ragged - fuzz * dither || y < 0.0 || y > 1.0 || split * split_line > 0.5) {
		discard;
	}
	float px = max(fwidth(bph), 1e-4);
	float barb_k = 1.0 - smoothstep(0.35, 0.9, px);
	float barb = 1.0 - smoothstep(0.0, 0.35, abs(fract(bph) - 0.5) * 2.0 - 0.6);
	vec3 col = v_col.rgb;
	// el plumón de la base (casi siempre tapado): algo más claro
	float down = 1.0 - smoothstep(0.04, 0.18, y);
	if (k < 1.5) {
		col = mix(col, mix(col, down_color, 0.35), down);
	}
	// el dibujo
	if (pat > 0.5 && pat < 1.5) {
		float b = sin((y - abs(x) * 0.12) * par * 3.1416 * 2.0);
		col = mix(col, bar_color, smoothstep(0.2, 0.55, b) * smoothstep(0.1, 0.3, y));
	} else if (pat > 1.5 && pat < 2.5) {
		float st = 1.0 - smoothstep(0.12, 0.24, abs(x) / (0.25 + 0.35 * y));
		col = mix(col, bar_color, st * smoothstep(0.25, 0.45, y) * (1.0 - smoothstep(0.92, 1.0, y)));
	} else if (pat > 2.5 && pat < 3.5) {
		float r = length(vec2(x * 0.9, (y - 0.8) * 1.6));
		col = mix(col, bar_color, 1.0 - smoothstep(0.12, 0.17, r));
		col = mix(col, edge_color, 1.0 - smoothstep(0.05, 0.09, r));
	} else if (pat > 3.5 && pat < 4.5) {
		float fr = smoothstep(-0.16, -0.03, edge) * smoothstep(0.45, 0.8, y) + smoothstep(0.93, 0.99, y) * 0.5;
		col = mix(col, edge_color, clamp(fr, 0.0, 1.0) * 0.6);
	} else if (pat > 4.5 && pat < 5.5) {
		col = mix(col, bar_color, smoothstep(0.78, 0.82, y) * (1.0 - smoothstep(0.88, 0.91, y)));
		col = mix(col, edge_color, smoothstep(0.92, 0.95, y));
	} else if (pat > 5.5) {
		float v = abs(x) * 0.7 + (0.86 - y);
		col = mix(col, bar_color, (1.0 - smoothstep(0.05, 0.1, abs(v - 0.12))) * step(0.55, y));
	}
	// las barbas: líneas finas algo más oscuras, que se desvanecen cuando miden menos de un píxel; y su grano a una escala
	// mayor (las barbas se juntan en grupos y cada grupo tiene su tono): de lejos la pluma sigue teniendo textura
	col *= 1.0 - (k < 0.5 ? 0.07 : 0.15) * barb * barb_k;
	float grp = floor(bph / 6.0);
	float gtone = hash12(vec2(grp, seed * 53.0 + sign(x)));
	float gk = 1.0 - smoothstep(0.5, 1.6, fwidth(bph / 6.0));
	col *= mix(1.0, 0.9 + 0.18 * gtone, gk * (k < 0.5 ? 0.5 : 1.0));
	// la parte tapada por la pluma de encima, en sombra; la punta, a la luz
	col *= k < 1.5 ? mix(0.82, 1.04, smoothstep(0.2, 0.75, y)) : 1.0;
	// el raquis
	float rw = mix(0.075, 0.012, y);
	float shaft = 1.0 - smoothstep(rw * 0.55, rw, abs(x));
	float smix = shaft_mix * (k < 0.5 ? 0.0 : (k < 1.5 || k > 3.5 ? 0.3 : 1.0));
	col = mix(col, shaft_color * mix(vec3(1.0), col * 1.6, 0.5), shaft * smix);
	// la barba de fuera de las rémiges, algo más oscura; el envés, más apagado
	col *= k > 1.5 && k < 2.5 && x > 0.0 ? 0.85 : 1.0;
	col *= FRONT_FACING ? 1.0 : 0.78;
	col *= 0.92 + 0.16 * hash12(vec2(seed * 71.0, 3.0));
	ALBEDO = col * v_col.a;
	ROUGHNESS = mix(0.8, 0.5, shaft * smix);
	SPECULAR = 0.16 + sheen * 0.4 * (1.0 - down);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
