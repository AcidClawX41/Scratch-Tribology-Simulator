// Daños del coche en marcha en el propio material de la chapa (unidad 4k): los lee car_paint.gdshader y, para que las
// piezas pegadas a la chapa sigan una abolladura, car_part.gdshader. Todo sale de impact() o hold_report() a través del
// estado (car3d/car_damage.gd los convierte en estas listas, en metros del coche); aquí solo se pintan, a su escala real
// (un surco de 0,27 mm no llega a un píxel: se dibuja de un píxel, con el color de la capa a la que llega).
// Coordenadas: las del objeto (m; x desde la zaga, y hacia arriba, z hacia quien mira). Cada daño va en un plano: «arriba»
// (eje 0: coordenadas x, z; la chapa mira hacia +y) o «costado» (eje 1: x, y; la chapa mira hacia +z).
// Compatible con Forward+, Mobile y Compatibility (sin Decal, que Compatibility no pinta).

const int MAX_GROOVES = 48;
const int MAX_HOLES = 40;
const int MAX_DENTS = 16;

// Surcos, ranuras y tajos: a y b (x0, v0, x1, v1), y (medio ancho m, capa + hondura µm / 10000, eje + 2·labio, golpe +
// forma). Forma (unidad 4y): la parte del surco entero que cubre el tramo, (32·t0 + t1)/2048 con t0 y t1 en treintaunavos.
// Capa: 0 barniz · 1 color · 2 imprimación · 3 anticorrosivo (o promotor) · 4 la carrocería (metal o plástico) ·
// 5 la atraviesa (hueco oscuro con el borde de la carrocería). Labio: su altura entre la hondura, en milésimas (0-500).
// Van empaquetados en tres números para no pasar del máximo de uniformes del renderizador Compatibility en los móviles.
uniform int n_grooves = 0;
uniform vec4 groove_ab[MAX_GROOVES];
uniform vec4 groove_p[MAX_GROOVES];
// Agujeros: (x, v, radio m, pétalos: 0 = plástico) y (eje, golpe, semilla, 0). Punzadas sin atravesar (unidad 4s): (x, v,
// radio m en la superficie, −1 − labio entre hondura) y (eje, golpe, semilla, hondura µm > 0).
uniform int n_holes = 0;
uniform vec4 hole_c[MAX_HOLES];
uniform vec4 hole_p[MAX_HOLES];
// Abolladuras: (centro xyz, radio m) y (profundidad m, eje, radio del fondo m, golpe).
uniform int n_dents = 0;
uniform vec4 dent_c[MAX_DENTS];
uniform vec4 dent_p[MAX_DENTS];
// El golpe que se está animando (sus daños crecen con la abolladura y el resbalón, 0-1); los demás, enteros.
uniform float current_hit = -1.0;
uniform float hit_crush = 1.0;
uniform float hit_slide = 1.0;

float dmg_progress_crush(float hit) {
	return abs(hit - current_hit) < 0.5 ? hit_crush : 1.0;
}

float dmg_progress_slide(float hit) {
	return abs(hit - current_hit) < 0.5 ? hit_slide : 1.0;
}

vec2 dmg_plane(vec3 p, int axis) {
	return axis == 0 ? p.xz : p.xy;
}

vec3 dmg_axis(int axis) {
	return axis == 0 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
}

// Abolladuras: lo que se hunde el punto p (a lo largo de la normal de su panel) y la pendiente del hundimiento en el plano
// del panel (para inclinar la normal: el reflejo se deforma). Perfil: el fondo (el apoyo) hundido del todo y un borde
// suave hasta el radio R (dibujo: la física da la profundidad; el radio, docs/fisica/coche-en-marcha.md §9.6).
void dent_field(vec3 p, out vec3 disp, out vec3 grad) {
	disp = vec3(0.0);
	grad = vec3(0.0);
	for (int i = 0; i < MAX_DENTS; i++) {
		if (i >= n_dents) {
			break;
		}
		vec4 c = dent_c[i];
		vec4 q = dent_p[i];
		int axis = int(q.y + 0.5);
		vec3 ax = dmg_axis(axis);
		if (dot(p - c.xyz, ax) < -0.3) {
			continue;  // la otra cara del coche
		}
		vec2 d2 = dmg_plane(p, axis) - dmg_plane(c.xyz, axis);
		float r = length(d2);
		float big = c.w;
		float core = min(q.z, big * 0.8);
		if (r >= big) {
			continue;
		}
		float depth = q.x * dmg_progress_crush(q.w);
		float t = clamp((r - core) / max(big - core, 1e-4), 0.0, 1.0);
		float f = 1.0 - t * t * (3.0 - 2.0 * t);
		disp -= ax * depth * f;
		float dfdr = -6.0 * t * (1.0 - t) / max(big - core, 1e-4);
		vec2 g = r > 1e-6 ? d2 / r * (depth * dfdr) : vec2(0.0);
		grad += axis == 0 ? vec3(g.x, 0.0, g.y) : vec3(g.x, g.y, 0.0);
	}
}

// Distancia de p al segmento a-b.
float dmg_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-12), 0.0, 1.0);
	return length(pa - ba * h);
}

float dmg_hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Unidad 4y: la forma de un tramo de surco, de la parte fraccionaria del número del golpe: (t0, t1), la parte del surco entero
// que cubre (sin forma, el surco entero).
vec2 dmg_shape(float w) {
	float code = floor(fract(w + 1e-6) * 2048.0 + 0.5);
	if (code < 0.5) {
		return vec2(0.0, 1.0);
	}
	return vec2(floor(code / 32.0) / 31.0, mod(code, 32.0) / 31.0);
}

// Unidad 4y (juego, como las marcas de garras muy detalladas de los videojuegos): el ancho relativo a lo largo del surco
// entero (T de 0 a 1): la punta entra fina, se ensancha hasta morder del todo, se estrecha al final y, al levantarse, arranca
// una escama de pintura algo más ancha; cada garra (k) un poco distinta.
float dmg_taper(float T, float k) {
	float enter = mix(0.35, 1.0, smoothstep(0.0, 0.2, T));
	float drag = 1.0 - 0.45 * smoothstep(0.72, 0.95, T);
	float flake = 0.55 * smoothstep(0.93, 1.0, T) * (0.6 + 0.4 * sin(k * 3.7 + 1.3));
	return enter * drag + flake;
}

// Capas de la pintura (µm desde la superficie: dónde acaba el barniz, el color, la imprimación y el anticorrosivo) y el
// espesor de la pintura con la carrocería (µm): con ellas, la hondura de cada punto de un surco o de una punzada decide la
// capa que se ve ahí (las paredes enseñan las capas que cortan, en terrazas, y el fondo la más honda). Las pone la vista
// con las capas del coche elegido (Catalog.car_layers).
uniform vec4 paint_to_um = vec4(45.0, 60.0, 85.0, 110.0);
// Unidad 4s: lo que se exagera la altura de los labios en el relieve y en su brillo (1 = la de la física; el primer plano en
// toda la vista lo sube para que se vean los de un surco fino: dibujo).
uniform float lip_boost = 1.0;
uniform float panel_um = 810.0;

// La capa (0-5) a la hondura z (µm): 0 barniz · 1 color · 2 imprimación · 3 anticorrosivo · 4 la carrocería · 5 la atraviesa.
float dmg_layer_at(float z_um) {
	if (z_um >= panel_um - 1e-3) {
		return 5.0;
	}
	if (z_um > paint_to_um.w) {
		return 4.0;
	}
	if (z_um > paint_to_um.z) {
		return 3.0;
	}
	if (z_um > paint_to_um.y) {
		return 2.0;
	}
	if (z_um > paint_to_um.x) {
		return 1.0;
	}
	return 0.0;
}

// De un plano (eje 0: x, z; eje 1: x, y) a 3D.
vec3 dmg_unplane(vec2 v, int axis) {
	return axis == 0 ? vec3(v.x, 0.0, v.y) : vec3(v.x, v.y, 0.0);
}

// Lo que se ve de los surcos, las punzadas y los agujeros en p (objeto) con normal n (objeto) y px (m por píxel en la
// chapa). Devuelve x, la cobertura (0-1); y, la capa (0-5); z, 1 si es el borde de un hueco o un labio (el metal o el
// plástico a la vista, o la pintura levantada); w, lo que se oscurece (pétalos doblados hacia dentro). Además, en relief:
// xyz, lo que se inclina la normal (objeto) por el relieve, y w, la oclusión (1 a la luz, 0 en el fondo de un hueco
// estrecho); en lip, lo que sube un labio (0-1: el brillo de la rebaba).
// Los perfiles (unidad 4s), con los números del motor que trae cada marca: el surco es una parábola de su ancho
// (widthUm) y su hondura (depthUm), z = D·(1 − (s/w)²); a cada lado, un labio de la anchura del medio surco con el
// volumen que el arado aparta y no arranca, (1 − f_ab) (Hokkirigawa y Kato 1988), que da una altura (1 − f_ab)·D; la
// punzada es el cono de la punta, de su diámetro (holeUm) y su hondura, con el mismo labio alrededor. Dónde va cada uno y la
// irregularidad del borde son dibujo.
vec4 damage_marks_ex(vec3 p, vec3 n, float px, out vec4 relief, out float lip) {
	vec4 best = vec4(0.0, 0.0, 0.0, 0.0);
	relief = vec4(0.0, 0.0, 0.0, 1.0);
	lip = 0.0;
	float best_z = -1.0;
	for (int i = 0; i < MAX_GROOVES; i++) {
		if (i >= n_grooves) {
			break;
		}
		vec4 gp = groove_p[i];
		int axis = int(mod(gp.z, 2.0) + 0.5);
		if (dot(n, dmg_axis(axis)) < 0.35) {
			continue;
		}
		float lipk = floor(gp.z * 0.5 + 0.01) / 500.0;
		float layer0 = floor(gp.y + 1e-4);
		float depth_um = fract(gp.y + 1e-4) * 10000.0;
		vec4 ab = groove_ab[i];
		vec2 a = ab.xy;
		float hitn = floor(gp.w + 1e-4);
		vec2 tt = dmg_shape(gp.w);
		vec2 b = mix(a, ab.zw, dmg_progress_slide(hitn));
		vec2 uv = dmg_plane(p, axis);
		vec2 ba = b - a;
		float L2 = max(dot(ba, ba), 1e-12);
		float h = clamp(dot(uv - a, ba) / L2, 0.0, 1.0);
		vec2 q = uv - (a + ba * h);
		float d = length(q);
		float hw = gp.x;
		// el borde algo irregular a lo largo (dibujo: lo que arranca la punta no es una regla)
		float along = h * sqrt(L2);
		hw *= 1.0 + 0.08 * sin(along / max(hw, 1e-6) * 0.9 + float(i) * 1.7) + 0.05 * sin(along / max(hw, 1e-6) * 2.3 + float(i));
		// unidad 4y: el ancho a lo largo del surco entero (empieza fino, se ensancha donde la garra muerde y acaba con un
		// arrastre y la pintura arrancada al levantarse); la hondura, con él (juego: el ancho y la hondura de la física son
		// los de donde más muerde)
		float T = mix(tt.x, tt.y, h);
		float shape = dmg_taper(T, float(i));
		hw *= shape;
		depth_um *= clamp(shape, 0.45, 1.0);
		// unidad 4s (petición del 17-10: las marcas visibles sin la lupa): una marca más fina que un píxel se dibuja de un
		// píxel (dibujo; su ancho de verdad lo enseñan el primer plano y la lupa)
		float w = max(hw, px * 0.8);
		float lw = hw * 0.9 * (lip_boost > 1.0 ? 1.7 : 1.0);  // con los labios exagerados, también más anchos (dibujo)
		if (d > w + lw + px * 2.0) {
			continue;
		}
		// el extremo del surco, redondeado como la punta que lo hizo
		float cov = 1.0 - smoothstep(w - px * 0.5, w + px * 0.5, d);
		float layer = layer0;
		float is_lip = 0.0;
		float s = d / max(hw, 1e-9);
		vec2 u = d > 1e-9 ? q / d : vec2(0.0);
		bool resolved = hw > px * 1.5;
		if (layer0 > 4.5) {
			// atraviesa: el hueco en medio y, a cada lado, el borde de la carrocería (un píxel como poco)
			float lw5 = max(hw * 0.6, px * 0.9);
			float edge = 1.0 - smoothstep(w + lw5 - px * 0.5, w + lw5 + px * 0.5, d);
			if (cov < 0.5 && edge > 0.0) {
				cov = edge;
				layer = 4.0;
				is_lip = 1.0;
				if (resolved) {
					// el canto doblado hacia dentro: la normal mira al hueco
					relief.xyz -= dmg_unplane(u, axis) * 0.9 * edge;
				}
			} else if (cov >= 0.5) {
				relief.w = min(relief.w, 0.15);
			}
		} else if (resolved && d < hw) {
			// dentro del surco: la hondura de este punto decide la capa que se ve (las paredes, en terrazas)
			float z = depth_um * (1.0 - s * s);
			layer = dmg_layer_at(z);
			// la pared inclina la normal hacia el eje del surco: dz/ds = 2·D·s/w²
			float slope = 2.0 * depth_um * 1e-6 * s / max(hw, 1e-9);
			relief.xyz -= dmg_unplane(u, axis) * clamp(slope, 0.0, 2.5);
			// el fondo de un surco hondo y estrecho recibe menos luz
			float narrow = clamp(depth_um * 1e-6 / max(hw, 1e-9), 0.0, 1.5);
			relief.w = min(relief.w, 1.0 - 0.55 * narrow / 1.5 * (1.0 - s * s));
		}
		if (resolved && d >= hw && d < hw + lw && lipk > 0.0 && layer0 < 4.5) {
			// el labio: la pintura que el arado aparta a los lados, levantada (su altura, (1 − f_ab)·D)
			float t = (d - hw) / lw;
			float hl = lipk * depth_um * 1e-6 * lip_boost;
			float bump = sin(3.14159265 * t);
			float sl = 3.14159265 * hl / lw * cos(3.14159265 * t);
			relief.xyz += dmg_unplane(u, axis) * clamp(-sl, -2.0, 2.0);
			lip = max(lip, bump * clamp(hl / max(hw * 0.25, 1e-9), 0.0, 1.0));
			if (cov < 0.01) {
				// fuera del surco el labio sigue siendo la capa de arriba, con su brillo
				continue;
			}
		}
		// un surco más fino que un píxel se ve algo más tenue si solo raya la pintura; el que llega a la carrocería, entero
		cov *= clamp((layer0 > 3.5 ? 0.9 : 0.65) + hw / max(w, 1e-6), 0.65, 1.0);
		if (cov > best.x || (cov > 0.5 && best.x > 0.5 && layer > best.y)) {
			best = vec4(cov, layer, is_lip, 0.0);
		}
	}
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= n_holes) {
			break;
		}
		vec4 hp = hole_p[i];
		int axis = int(hp.x + 0.5);
		if (dot(n, dmg_axis(axis)) < 0.35) {
			continue;
		}
		vec4 hc = hole_c[i];
		float prog = dmg_progress_crush(hp.y);
		if (prog < 0.999) {
			continue;  // la marca aparece cuando la garra ya ha entrado
		}
		vec2 d2 = dmg_plane(p, axis) - hc.xy;
		float r = length(d2);
		vec2 u = r > 1e-9 ? d2 / r : vec2(0.0);
		float pit_um = hp.w;
		if (pit_um > 0.0) {
			// punzada: el cono de la punta, de su diámetro y su hondura, sin atravesar; su labio alrededor
			float rad = hc.z;
			float lipk = clamp(-hc.w - 1.0, 0.0, 1.0);
			// unidad 4y: una huella más pequeña que dos píxeles se dibuja de dos (dibujo, como los surcos de un píxel): la de cada
			// garra se ve en «Garras» de cerca; su tamaño de verdad, en «Marca»
			float wr = max(rad, px * 1.0);
			float lw = rad * 0.8;
			// unidad 4y (juego): la pintura saltada alrededor del cráter, de borde irregular, si la punta pasa del barniz
			float ang_p = atan(d2.y, d2.x);
			float chip_r = rad * (1.45 + 0.55 * (0.5 + 0.5 * sin(ang_p * 3.0 + hp.z * 21.0) * sin(ang_p * 7.0 + hp.z * 9.0)));
			bool chips = pit_um > paint_to_um.x * 0.6;
			if (r > max(wr + lw, chips ? chip_r : 0.0) + px * 2.0) {
				continue;
			}
			bool resolved = rad > px * 1.5;
			float cov = 1.0 - smoothstep(wr - px * 0.5, wr + px * 0.5, r);
			if (resolved && r < rad) {
				float z = pit_um * (1.0 - r / rad);
				float layer = dmg_layer_at(z);
				relief.xyz -= dmg_unplane(u, axis) * clamp(pit_um * 1e-6 / rad, 0.0, 2.5);
				relief.w = min(relief.w, 1.0 - 0.6 * clamp(pit_um * 1e-6 / rad, 0.0, 1.0) * (1.0 - r / rad));
				if (cov > best.x || layer > best.y) {
					best = vec4(cov, layer, 0.0, 0.0);
				}
				continue;
			}
			if (resolved && chips && r < chip_r && best.x < 0.85) {
				best = vec4(0.85, min(1.0, dmg_layer_at(pit_um)), 0.0, 0.0);
			}
			if (resolved && r < rad + lw && lipk > 0.0) {
				float t = (r - rad) / lw;
				float hl = lipk * pit_um * 1e-6 * lip_boost;
				relief.xyz += dmg_unplane(u, axis) * clamp(-3.14159265 * hl / lw * cos(3.14159265 * t), -2.0, 2.0);
				lip = max(lip, sin(3.14159265 * t) * clamp(hl / max(rad * 0.25, 1e-9), 0.0, 1.0));
				continue;
			}
			if (!resolved && cov > best.x) {
				best = vec4(cov * 0.8, dmg_layer_at(pit_um), 0.0, 0.0);
			}
			continue;
		}
		float rad = max(hc.z, px * 0.6);
		float petals = hc.w;
		float reach = petals > 0.5 ? rad * 2.3 : rad * 1.6;
		// unidad 4y (juego): la pintura saltada alrededor de los pétalos, de borde irregular
		float flaked = reach * (1.12 + 0.28 * (0.5 + 0.5 * sin(atan(d2.y, d2.x) * 5.0 + hp.z * 13.0)));
		if (r > max(reach, petals > 0.5 ? flaked : 0.0) + px * 2.0) {
			continue;
		}
		float ang = atan(d2.y, d2.x) + hp.z * 6.2831853;
		// el borde desgarrado: el radio del agujero cambia con el ángulo
		float torn = rad * (1.0 + 0.16 * sin(ang * 5.0 + hp.z * 17.0) + 0.1 * sin(ang * 11.0 + hp.z * 5.0));
		if (r < torn) {
			best = vec4(1.0, 5.0, 0.0, 0.0);
			relief.w = min(relief.w, 0.1);
			continue;
		}
		// el borde desgarrado: el canto de la carrocería a la vista (el metal brilla; el plástico se blanquea)
		float lipw = max(px * 0.8, rad * 0.14);
		if (r < torn + lipw) {
			best = vec4(1.0, 4.0, 1.0, 0.0);
			relief.xyz -= dmg_unplane(u, axis) * 1.2;
			continue;
		}
		if (petals > 0.5) {
			// chapa que se rompe en pétalos (Wierzbicki 1999): grietas radiales y los pétalos doblados hacia dentro, más
			// oscuros cuanto más cerca del agujero; en las grietas, el metal a la vista
			float sector = fract(ang / 6.2831853 * petals);
			float arc = min(sector, 1.0 - sector) * 6.2831853 / petals * r;
			float k = 1.0 - clamp((r - rad) / (reach - rad), 0.0, 1.0);
			float open = rad * 0.35 * k;
			if (r < reach) {
				// el pétalo doblado hacia dentro: su normal se inclina hacia el agujero, más cerca de él
				relief.xyz -= dmg_unplane(u, axis) * 1.1 * k * k;
				relief.w = min(relief.w, 1.0 - 0.45 * k);
				if (arc < open + lipw * 0.7) {
					best = vec4(1.0, arc < open ? 5.0 : 4.0, arc < open ? 0.0 : 1.0, 0.0);
				} else if (best.x < 0.5) {
					// el pétalo sigue pintado por fuera: solo se oscurece (está doblado hacia dentro)
					best.w = max(best.w, 0.55 * k);
				}
			} else if (r < flaked && best.x < 0.5 && rad > px * 1.5) {
				best = vec4(0.85, 2.0, 0.0, 0.0);
			}
		} else if (r < reach) {
			// plástico: el labio blanqueado por el desgarro
			if (best.x < 0.9) {
				best = vec4(1.0, 4.0, 1.0, 0.0);
			}
		}
	}
	return best;
}

// Lo mismo sin el relieve (las lunas).
vec4 damage_marks(vec3 p, vec3 n, float px) {
	vec4 relief;
	float lip;
	return damage_marks_ex(p, n, px, relief, lip);
}


// Unidad 4y (juego): el microastillado del vidrio a los lados de la raya de una garra más dura que él (conchas pequeñas
// pegadas al borde, cada pocas veces su ancho, de un lado o del otro). Devuelve la cobertura (0-1).
float dmg_glass_chips(vec3 p, vec3 n, float px) {
	float best = 0.0;
	for (int i = 0; i < MAX_GROOVES; i++) {
		if (i >= n_grooves) {
			break;
		}
		vec4 gp = groove_p[i];
		int axis = int(mod(gp.z, 2.0) + 0.5);
		if (dot(n, dmg_axis(axis)) < 0.35) {
			continue;
		}
		float hw = gp.x;
		if (hw < px * 0.7) {
			continue;
		}
		vec4 ab = groove_ab[i];
		vec2 a = ab.xy;
		vec2 b = mix(a, ab.zw, dmg_progress_slide(floor(gp.w + 1e-4)));
		vec2 uv = dmg_plane(p, axis);
		vec2 ba = b - a;
		float L = length(ba);
		if (L < 1e-9) {
			continue;
		}
		vec2 t = ba / L;
		vec2 nn = vec2(-t.y, t.x);
		float along = dot(uv - a, t);
		float across = dot(uv - a, nn);
		if (along < 0.0 || along > L || abs(across) > hw * 3.2) {
			continue;
		}
		float cellw = hw * 2.2;
		float cell = floor(along / cellw);
		float hs = dmg_hash(cell * 7.31 + float(i) * 1.7);
		if (hs < 0.45) {
			continue;
		}
		float sgn = dmg_hash(cell * 3.17 + float(i)) > 0.5 ? 1.0 : -1.0;
		float rc = hw * (0.6 + 0.9 * dmg_hash(cell * 5.91 + float(i) * 0.3));
		vec2 c = vec2((cell + 0.5) * cellw, sgn * hw);
		float dd = length(vec2(along, across) - c);
		best = max(best, 1.0 - smoothstep(rc - px * 0.5, rc + px * 0.5, dd));
	}
	return best;
}
