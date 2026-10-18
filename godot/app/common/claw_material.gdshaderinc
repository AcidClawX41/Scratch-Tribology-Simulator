// Biblioteca de materiales de las garras (unidad 5e): el modelo de sombreado común de claw_solid.gdshader,
// claw_gem.gdshader y el estuche de la cetrería (lab/cetreria/keratin.gdshader). Los números físicos (F0 de los metales,
// índices por canal, absorción por milímetro, rugosidad de cada acabado) salen de core/lab/claw_optics.gd con su fuente;
// lo demás es dibujo y se dice.
//   - Metal y mineral opaco: metálico, con el color de su reflectancia medida (ALBEDO = F0 en sRGB lineal) y la rugosidad
//     de su superficie; las rayas de la herramienta, en su dirección.
//   - Gema y vidrio: el reflejo exterior lo pone la luz de Godot (SPECULAR con el F0 de su índice; el entorno con la sonda
//     o el cielo de la escena); lo que entra se refracta por canal con su índice (el «fuego»: cada canal sale por otro
//     sitio), rebota en la cara de atrás (reflexión total si pasa del ángulo crítico), se tiñe con Beer–Lambert (la
//     absorción por mm de cada canal por el camino dentro) y sale al entorno: el de la nave del taller o el de la
//     carretera, el mismo dibujo que sus cielos (workshop_sky, road_sky), evaluado aquí para que funcione igual en
//     Forward+, Mobile y Compatibility. Con la pantalla (claw_gem), lo que sale por detrás es lo que hay detrás.
//     Los birrefringentes promedian sus dos rayos (el desdoblamiento de las aristas de la moissanita).
//   - Cerámica: blanca difusa con su reflejo; queratina: su color con las líneas de crecimiento, las capas del estuche y
//     las estrías finas, y su capa de barniz.
//   - Superficie: la del acabado (pulido, tallado, limado…) o, si la escena la pasa (surface_tex con surface_range: la
//     superficie del motor de la cetrería, una columna por estación a lo largo de s), la de cada estación: R = Ra en escala logarítmica de 0,01 a 50 µm (la
//     rugosidad, de pulido espejo a mate, y la fuerza del rayado), A = dirección del rayado/180° respecto al eje de la
//     garra, G = quemado (oscurece y apaga el brillo) y B = desconchón (rompe la normal). Sin mover un vértice: la forma
//     es la de la malla, que sale de los datos de cada animal.
// Malla: UV.x = s (mm desde la base, a lo largo de la línea media), UV.y = vuelta alrededor de la línea media (0-1, 0
// arriba), UV2.x = radio (mm), como las de la cetrería (claw_mesh.gd) y las de la biblioteca (claw_geo.gd). Con
// claw_uv_mode = 1 (otra malla: UV.x alrededor), sin facetas ni mellas por celda.

uniform int claw_kind = 0; // 0 queratina · 1 metal o mineral · 2 gema o vidrio · 3 cerámica · 4 polímero
uniform vec3 claw_f0 = vec3(0.046);
uniform vec3 claw_base : source_color = vec3(0.18, 0.16, 0.15);
uniform vec3 claw_ior = vec3(1.549);
uniform vec3 claw_ior_e = vec3(1.549);
uniform vec3 claw_absorb = vec3(0.0);
uniform vec3 claw_tint = vec3(1.0);
uniform float claw_spec = 0.54;
uniform float claw_rough = 0.3;
uniform float claw_frost = 0.0;
uniform float claw_scatter = 0.0; // lo que difunde el cuerpo de un polímero (0 transparente, 1 opaco)
uniform float claw_facets = 0.0;
uniform float claw_facet_mm = -1.0; // largo de cada faceta (mm); < 0: un 20 % del largo de la garra
uniform float claw_scratch = 0.0;
uniform float claw_scratch_deg = 0.0;
uniform float claw_chips = 0.0;
uniform float claw_cracks = 0.0;
uniform float claw_oxide = 0.0;
uniform vec3 claw_oxide_color : source_color = vec3(0.12, 0.11, 0.1);
uniform vec3 claw_char_color : source_color = vec3(0.05, 0.035, 0.025);
uniform float claw_burn = 0.0;
uniform float claw_pores = 0.0;
uniform float claw_clear = 0.0;
uniform float claw_growth = 0.0;
uniform float claw_clearcoat = 0.0;
uniform float claw_clearcoat_rough = 0.08;
uniform float claw_env = 0.0; // 0 nave del taller · 1 carretera
uniform float claw_env_energy = 1.0;
// unidad 4w: el cielo de la carretera que se ve en las garras sigue a la luz del coche (CarScene.set_light, a través de
// ClawMaterial.road_light): por defecto, el atardecer de siempre (road_sky.gdshader), tal cual
uniform vec3 claw_road_sun_dir = vec3(0.42, 0.8, 0.45);
uniform vec3 claw_road_sun_color = vec3(1.0, 0.86, 0.66);
uniform float claw_road_sun_k = 30.0;
uniform vec3 claw_road_zenith = vec3(0.15, 0.14, 0.24);
uniform vec3 claw_road_mid = vec3(0.27, 0.26, 0.31);
uniform vec3 claw_road_horizon = vec3(0.92, 0.80, 0.70);
// lo de abajo: cerca, lo que pisa la garra (en el coche, su pintura: una garra sobre un coche rojo refleja rojo); lejos, el
// asfalto. Y cuánto se acerca al blanco lo que se ve dentro de una gema (0 nada): el cielo dibujado de la carretera es más
// morado y más oscuro que uno de verdad, y un diamante se veía lila y con caras negras (dibujo)
uniform vec3 claw_road_ground_near = vec3(0.19, 0.17, 0.19);
uniform vec3 claw_road_ground = vec3(0.07, 0.06, 0.08);
uniform float claw_road_neutral = 0.0;
// el sol visto desde dentro de una gema (dibujo, unidad 4w): un lóbulo más ancho que su disco de medio grado, para que las
// caras que lo alcanzan (cada canal con su índice, por eso con color: el fuego) dominen sobre las que ven el asfalto
uniform float claw_road_gem_sun = 0.0;
uniform float claw_thick_mm = 4.0;
// una sección comprimida de lado (alto/ancho = k; la hoz del velocirraptor, en la cetrería): lo que absorbe una gema va a
// lo largo de su ancho, 2·r/√k, y no del diámetro de la sección redonda equivalente. Con 1 (lo de todos), como siempre.
uniform float claw_section_k = 1.0;
uniform float claw_seed = 0.0;
uniform int claw_uv_mode = 0;
uniform int claw_quality = 0; // 0 escritorio · 1 teléfono (un rayo por canal, sin el segundo rebote)
// la superficie de la cetrería (contrato «La cetrería en alta definición y la superficie de la garra»)
uniform sampler2D surface_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 surface_range = vec2(0.0, 0.0);

struct ClawOut {
	vec3 albedo;
	vec3 emission;
	vec3 normal;
	float rough;
	float metal;
	float spec;
	float backlight;
	float clearcoat;
	float burn;
};

struct ClawSurf {
	float rough;
	float scratch;
	float scratch_deg;
	float burn;
	float chip;
};

float claw_hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float claw_hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Lo que cambia la vuelta a de un píxel al de al lado, sin el salto de la costura (de 1 a 0): entre dos píxeles vecinos,
// a cambia mucho menos de media vuelta.
float claw_da(float d) {
	return d - round(d);
}

// Rugosidad de Godot de una rugosidad rms σ (µm): la misma cuenta que ClawMaterial.roughness_of (dibujo: de espejo,
// 5 nm, a mate, micras, en escala logarítmica).
float claw_roughness_of(float sigma_um) {
	float nm = max(sigma_um * 1000.0, 0.0);
	return clamp(0.03 + 0.2 * log(max(nm / 5.0, 1.0)) / log(10.0), 0.03, 0.75);
}

// ── El entorno (dibujo: los cielos de la nave del taller y de la carretera, con un difuminado para lo rugoso) ──

vec3 claw_env_workshop(vec3 d, float blur) {
	vec3 ceiling = vec3(0.13, 0.135, 0.14);
	vec3 wall = vec3(0.72, 0.76, 0.76);
	vec3 wall_low = vec3(0.55, 0.6, 0.6);
	vec3 floor_c = vec3(0.46, 0.5, 0.5);
	vec3 lamp = vec3(1.0, 0.97, 0.92) * 7.0;
	vec3 win = vec3(0.78, 0.86, 0.96) * 1.4;
	float soft = 1.0 + 30.0 * blur;
	vec3 col;
	if (d.y > 0.0) {
		float t_ceil = 5.5 / max(d.y, 1e-4);
		float t_wall = 12.0 / max(max(abs(d.x), abs(d.z)), 1e-4);
		if (t_ceil < t_wall) {
			vec2 p = d.xz * t_ceil;
			vec2 cell = vec2(mod(p.x + 2.0, 4.0) - 2.0, mod(p.y + 1.5, 3.0) - 1.5);
			float lx = 1.0 - smoothstep(0.70, 0.70 + 0.02 * soft, abs(cell.x));
			float lz = 1.0 - smoothstep(0.09, 0.09 + 0.01 * soft, abs(cell.y));
			float fade = exp(-length(p) * 0.035);
			col = ceiling * (0.75 + 0.25 * fade) + lamp * lx * lz * fade / mix(1.0, soft * 0.6, 0.5);
		} else {
			vec3 hit = d * t_wall;
			float h = hit.y + 1.6;
			float w = smoothstep(2.9, 2.9 + 0.2 * soft, h) * (1.0 - smoothstep(4.6, 4.6 + 0.2 * soft, h));
			float u = abs(d.x) > abs(d.z) ? hit.z : hit.x;
			float mull = 1.0 - smoothstep(0.90, 0.90 + 0.05 * soft, abs(mod(u, 2.0) - 1.0));
			col = mix(wall_low, wall, smoothstep(0.0, 2.5, h)) + win * w * mull;
		}
	} else {
		col = floor_c * (0.9 + 0.1 * smoothstep(-0.2, 0.0, d.y));
	}
	return col;
}

vec3 claw_env_road(vec3 d, float blur) {
	vec3 zenith = claw_road_zenith;
	vec3 mid = claw_road_mid;
	vec3 horizon = claw_road_horizon * 0.95;
	vec3 sun_dir = normalize(claw_road_sun_dir);
	vec3 col;
	if (d.y >= 0.0) {
		col = mix(mid, zenith, smoothstep(0.08, 0.85, d.y));
		col = mix(horizon, col, smoothstep(0.0, 0.22 + 0.3 * blur, d.y));
		float s = max(dot(d, sun_dir), 0.0);
		float sharp = mix(900.0, 40.0, clamp(blur, 0.0, 1.0));
		col += claw_road_sun_color * (pow(s, sharp) * claw_road_sun_k * mix(1.0, 0.08, clamp(blur, 0.0, 1.0)) + pow(s, 12.0) * 0.55 + pow(s, 3.0) * 0.12);
	} else {
		col = mix(claw_road_ground_near, claw_road_ground, smoothstep(0.0, 0.35, -d.y));
		col = mix(horizon * 0.35, col, smoothstep(0.0, 0.06 + 0.2 * blur, -d.y));
	}
	return col;
}

vec3 claw_env_at(vec3 d, float blur) {
	vec3 n = normalize(d);
	return (claw_env > 0.5 ? claw_env_road(n, blur) : claw_env_workshop(n, blur)) * claw_env_energy;
}

// ── Los puntos de luz pequeños (dibujo, unidad 5p): bombillas, focos LED y destellos de la sala, de 0,25-0,5° de radio y
// muy brillantes (de 18 a 45 veces el blanco). Son los que dejan ver el fuego: cada canal sale de la gema con su ángulo
// (la dispersión medida de cada material, sin exagerarla) y un punto de luz más pequeño que esa separación lo alcanza un
// canal y los otros no: un destello de color. Dentro de una gema tallada cada bombilla se ve muchas veces (cada camino
// entre las facetas la ve desde otro sitio): density = 1 es esa multitud; un reflejo de fuera ve las pocas de la sala
// (density pequeña). Una rejilla en las seis caras de un cubo de direcciones (22 celdas de ~4° por lado), con uno o ningún
// punto por celda, en un sitio, de un tamaño y con un brillo al azar, fijos (no parpadean); más en lo alto (el techo) que
// en las paredes y casi ninguno abajo. En una superficie rugosa o esmerilada se apagan (su luz se reparte).
vec3 claw_env_spots(vec3 d, float blur, float density) {
	float vis = 1.0 - smoothstep(0.05, 0.35, blur);
	if (vis <= 0.0) {
		return vec3(0.0);
	}
	vec3 ad = abs(d);
	vec2 uv;
	float face;
	if (ad.x >= ad.y && ad.x >= ad.z) {
		uv = d.zy / ad.x;
		face = d.x > 0.0 ? 0.0 : 1.0;
	} else if (ad.y >= ad.z) {
		uv = d.xz / ad.y;
		face = d.y > 0.0 ? 2.0 : 3.0;
	} else {
		uv = d.xy / ad.z;
		face = d.z > 0.0 ? 4.0 : 5.0;
	}
	vec2 g = (uv * 0.5 + 0.5) * 22.0;
	vec2 cell = floor(g);
	float region = d.y > 0.25 ? 0.55 : (d.y > -0.15 ? 0.32 : 0.05);
	if (claw_hash21(cell + face * 37.0) > region * density) {
		return vec3(0.0);
	}
	float h2 = claw_hash21(cell.yx + face * 11.0 + 5.3);
	float h3 = claw_hash21(cell + face * 19.0 + 2.9);
	vec2 c = vec2(0.3 + 0.4 * h3, 0.3 + 0.4 * h2);
	float spread = 1.0 + 2.5 * smoothstep(0.0, 0.35, blur);
	float r = mix(0.06, 0.12, fract(h2 * 3.7)) * spread;
	float core = 1.0 - smoothstep(r * 0.55, r, length(g - cell - c));
	return vec3(1.0, 0.96, 0.9) * core * mix(18.0, 45.0, fract(h3 * 13.1)) * vis * claw_env_energy / (spread * spread);
}

// ── Reflexión y refracción ──

// Fresnel exacto de un dieléctrico, sin polarizar, desde el lado de índice 1 hacia n (el de core: ClawOptics.fresnel).
float claw_fresnel(float cos_i, float n) {
	float ci = clamp(abs(cos_i), 0.0, 1.0);
	float st2 = (1.0 - ci * ci) / (n * n);
	if (st2 >= 1.0) {
		return 1.0;
	}
	float ct = sqrt(1.0 - st2);
	float rs = (ci - n * ct) / (ci + n * ct);
	float rp = (n * ci - ct) / (n * ci + ct);
	return 0.5 * (rs * rs + rp * rp);
}

// Lo que sale de la gema por un canal de índice n: el rayo entra por la cara de delante (nf), cruza el espesor, sale por
// la de atrás (nb, hacia fuera) o, si pasa del ángulo crítico, rebota y sale por delante (nf2). Devuelve la dirección de
// salida (mundo) en xyz y en w el camino recorrido dentro, en espesores (1 = de lado a lado).
vec4 claw_trace(vec3 v_in, vec3 nf, vec3 nb, vec3 nf2, float n, bool second) {
	vec3 t = refract(v_in, nf, 1.0 / n);
	if (dot(t, t) < 1e-6) {
		return vec4(reflect(v_in, nf), 0.0);
	}
	vec3 e = refract(t, -nb, n);
	if (dot(e, e) > 1e-6) {
		return vec4(e, 1.0);
	}
	vec3 r1 = reflect(t, -nb);
	if (!second) {
		return vec4(r1, 2.0);
	}
	vec3 e2 = refract(r1, -nf2, n);
	if (dot(e2, e2) > 1e-6) {
		return vec4(e2, 2.0);
	}
	return vec4(reflect(r1, -nf2), 3.0);
}

// ── La superficie en un punto: la de la escena (surface_tex) o la del acabado ──

ClawSurf claw_surface(float s_mm) {
	ClawSurf sf;
	sf.rough = claw_rough;
	sf.scratch = claw_scratch;
	sf.scratch_deg = claw_scratch_deg;
	sf.burn = claw_burn;
	sf.chip = 0.0;
	if (surface_range.y > surface_range.x + 1e-4) {
		float u = clamp((s_mm - surface_range.x) / (surface_range.y - surface_range.x), 0.0, 1.0);
		vec4 t = texture(surface_tex, vec2(u, 0.5));
		float ra = 0.01 * pow(5000.0, t.r); // R en escala logarítmica de 0,01 a 50 µm (ClawMaterial.surface_r)
		// σ ≈ 1,25·Ra (alturas gaussianas); el rayado se ve más cuanto más rugosa, hasta unas micras
		sf.rough = claw_roughness_of(1.25 * ra);
		sf.scratch = smoothstep(0.05, 2.0, ra);
		sf.scratch_deg = t.a * 180.0;
		sf.burn = max(sf.burn, t.g);
		sf.chip = t.b;
	}
	return sf;
}

// El largo de cada faceta de una talla (mm): el del material o, si no lo fija, un 20 % del largo de la garra (dibujo:
// biseles largos, de una talla a mano; así un mismo material sirve a garras de largos distintos).
float claw_facet_len(float apex_mm) {
	return claw_facet_mm > 0.0 ? claw_facet_mm : max(apex_mm * 0.2, 0.5);
}

// ── El acabado en la normal (espacio de la vista; ts, ta: tangentes a lo largo y alrededor) ──

vec3 claw_finish_normal(vec3 n, vec3 ts, vec3 ta, float s_mm, float a, float r_mm, float apex_mm, ClawSurf sf, inout float rough, inout float frost, inout float edge) {
	vec3 nn = n;
	edge = 0.0;
	if (claw_uv_mode == 0 && claw_facets > 2.5) {
		// facetas de una talla a mano: largas a lo largo de la garra (filas de claw_facet_len, al tresbolillo) y
		// claw_facets alrededor; cada una, plana (la normal de su centro) con su propia inclinación, de bisel en bisel
		float fa = a * claw_facets;
		float col = floor(fa);
		float stagger = mod(col, 2.0) * 0.5;
		float fs = s_mm / claw_facet_len(apex_mm) + stagger;
		float row = floor(fs);
		float ca = (col + 0.5) / claw_facets;
		float dphi = 6.2831853 * (ca - a);
		float id = claw_hash21(vec2(col + claw_seed * 7.0, row));
		float tilt = (mod(row + col, 2.0) - 0.5) * 0.22 + (id - 0.5) * 0.12;
		// la normal del centro de la faceta alrededor: la de aquí girada dphi hacia ta (con ta en el sentido en que crece a:
		// claw_tangents)
		vec3 nc = nn * cos(dphi) + ta * sin(dphi);
		// y a lo largo (unidad 5p): con lo que gira la superficie por milímetro (la curva de la garra, de las derivadas en la
		// pantalla), así cada faceta es un espejo plano y un punto de luz la enciende entera o a trozos, como en una gema
		// tallada (con la normal curva, solo un punto de un píxel)
		float s_c = (row + 0.5 - stagger) * claw_facet_len(apex_mm);
		float dsx = dFdx(s_mm);
		float dsy = dFdy(s_mm);
		float dax = claw_da(dFdx(a));
		float day = claw_da(dFdy(a));
		float det = dsx * day - dsy * dax;
		vec3 dnds = abs(det) > 1e-14 ? (dFdx(n) * day - dFdy(n) * dax) / det : vec3(0.0);
		// sin pasar de lo que gira una garra muy curva (~10°/mm), por si las derivadas saltan en el borde de la silueta
		dnds *= min(1.0, 0.17 / max(length(dnds), 1e-6));
		nc -= dnds * (s_mm - s_c);
		nn = normalize(nc + ts * tilt);
		float ea = abs(fract(fa) - 0.5);
		float es = abs(fract(fs) - 0.5);
		edge = smoothstep(0.475, 0.5, max(ea, es));
	}
	float sc = sf.scratch;
	if (sc > 0.0) {
		// rayas de la herramienta: surcos paralelos en la dirección sf.scratch_deg (0° a lo largo de la garra), con su
		// separación y su hondura algo distintas cada una; en mm sobre la superficie (s a lo largo, la vuelta alrededor)
		float th = radians(sf.scratch_deg);
		float around = a * 6.2831853 * max(r_mm, 0.3);
		float w = -s_mm * sin(th) + around * cos(th);
		float pitch = 0.11;
		float k = w / pitch;
		// de lejos, cuando un surco ocupa menos de un píxel, su relieve se convierte en rugosidad (sin muaré)
		float vis = 1.0 - smoothstep(0.35, 1.0, fwidth(k));
		float jitter = claw_hash11(floor(k) + claw_seed * 13.0);
		float depth = (0.35 + 0.65 * claw_hash11(floor(k * 0.31) + 5.0)) * (fract(k) - 0.5) * 2.0;
		vec3 perp = normalize(-ts * sin(th) + ta * cos(th));
		nn = normalize(nn + perp * depth * 0.16 * sc * (0.6 + 0.4 * jitter) * vis);
		rough = mix(rough, max(rough, 0.4), sc * 0.35 * mix(0.5, abs(depth), vis));
	}
	float chips = max(claw_chips, sf.chip * 3.0);
	if (chips > 0.0 && claw_uv_mode == 0) {
		// mellas y desconchones: escamas concoideas (las del acabado, en los últimos milímetros de la punta; las de la
		// superficie de la cetrería, donde las marca su estación)
		float zone = sf.chip > 0.0 ? sf.chip : smoothstep(apex_mm - 3.0, apex_mm - 0.4, s_mm);
		vec2 g = vec2(s_mm * 1.6, a * 9.0);
		vec2 cell = floor(g);
		float h = claw_hash21(cell + claw_seed);
		float chip = step(1.0 - 0.18 * chips, h) * zone;
		vec2 f = fract(g) - 0.5;
		nn = normalize(nn + (ts * f.x + ta * f.y) * 1.4 * chip);
		frost = max(frost, chip * 0.7);
		rough = mix(rough, 0.55, chip);
	}
	return nn;
}

// ── El modelo completo ──
// n_view, v_view: normal y vista (espacio de la vista); ts, ta: tangentes; s_mm, a, r_mm: dónde está el punto en la
// garra; apex_mm: dónde acaba; screen_behind: lo que hay detrás en la pantalla, por canal (si has_screen).
ClawOut claw_shade(vec3 n_view, vec3 v_view, vec3 ts, vec3 ta, float s_mm, float a, float r_mm, float apex_mm, mat4 inv_view, vec3 screen_behind[3], bool has_screen) {
	ClawOut o;
	o.albedo = vec3(0.0);
	o.emission = vec3(0.0);
	o.metal = 0.0;
	o.spec = claw_spec;
	o.backlight = 0.0;
	o.clearcoat = 0.0;
	ClawSurf sf = claw_surface(s_mm);
	o.rough = sf.rough;
	o.burn = clamp(sf.burn, 0.0, 1.0);
	float frost = claw_frost;
	if (claw_kind == 2 && surface_range.y > surface_range.x + 1e-4) {
		// una gema rayada se vuelve lechosa como el vidrio esmerilado (la misma cuenta que ClawMaterial.frost_of)
		frost = max(frost, smoothstep(0.08, 0.9, (o.rough - 0.03) * 2.0));
	}
	float edge = 0.0;
	vec3 n = claw_finish_normal(n_view, ts, ta, s_mm, a, r_mm, apex_mm, sf, o.rough, frost, edge);
	o.normal = n;
	float crack_k = 0.0;
	if (claw_cracks > 0.0 && claw_uv_mode == 0) {
		for (int i = 0; i < 4; i++) {
			if (float(i) >= claw_cracks) {
				break;
			}
			float ai = claw_hash11(float(i) * 7.3 + claw_seed);
			float s0 = apex_mm * (0.25 + 0.5 * claw_hash11(float(i) * 3.1 + 2.0));
			float len = apex_mm * 0.35;
			float wob = 0.012 * sin(s_mm * 3.0 + float(i));
			float d = abs(fract(a - ai + 0.5 + wob) - 0.5);
			crack_k = max(crack_k, (1.0 - smoothstep(0.004, 0.012, d)) * step(s0, s_mm) * step(s_mm, s0 + len));
		}
	}
	float burn = o.burn;
	if (claw_kind == 1) {
		// metal o mineral: el color de su reflectancia medida; el óxido de la reforja lo tiñe; lo quemado en la cetrería
		// (la queratina de debajo, el pegamento) deja hollín que lo oscurece y lo apaga: a ~230 °C ningún metal del
		// catálogo cambia de color por sí mismo
		o.albedo = claw_f0;
		o.metal = 1.0;
		o.albedo = mix(o.albedo, claw_oxide_color, claw_oxide * 0.85);
		o.metal = mix(o.metal, 0.2, claw_oxide);
		o.rough = mix(o.rough, 0.75, claw_oxide);
		o.albedo = mix(o.albedo, claw_char_color, burn * 0.8);
		o.metal = mix(o.metal, 0.0, burn * 0.9);
		o.rough = mix(o.rough, 0.85, burn);
		float pore = claw_pores * step(0.82, claw_hash21(floor(vec2(s_mm * 4.0, a * 40.0)) + claw_seed));
		o.albedo *= 1.0 - 0.6 * pore;
		o.albedo = mix(o.albedo, vec3(0.02), crack_k * 0.9);
		o.rough = mix(o.rough, 0.9, max(pore, crack_k));
		o.albedo *= 1.0 - 0.12 * edge;
		// Lo que refleja (unidad 5q, petición 56): un metal pulido es un espejo de su sala. El reflejo de Godot solo trae
		// el cielo de la escena (sin lámparas en Compatibility y Mobile; la sonda, solo en Forward+ y donde llega), así
		// que el acero salía gris plano y el oro apagado. Se suma el reflejo del entorno dibujado de la biblioteca (el
		// mismo que ven las gemas: la nave o la carretera, con sus lámparas, ventanas y puntos de luz), teñido por el F0
		// medido con el Fresnel de un conductor (Schlick: hacia el blanco en el borde) y difuminado por la rugosidad
		// (Bennett y Porteus en claw_roughness_of). Las rayas y los poros lo apagan; el óxido y el hollín, también.
		mat3 ivm = mat3(inv_view);
		vec3 nwm = normalize(ivm * n);
		vec3 vinm = -normalize(ivm * v_view);
		vec3 rdir = reflect(vinm, nwm);
		float blur_m = clamp(o.rough * 1.1, 0.0, 1.0);
		float cos_m = clamp(dot(n, v_view), 0.0, 1.0);
		vec3 f0m = clamp(o.albedo, 0.0, 1.0);
		vec3 fres = f0m + (vec3(1.0) - f0m) * pow(1.0 - cos_m, 5.0);
		// (sin los puntos de luz de las gemas: en un metal se ven como motas; sus lámparas ya van en el entorno) y con
		// un tope, para que el tonemap no blanquee el color del oro en el reflejo de una lámpara
		// claw_env_energy lo baja la escena que ya tiene sonda de reflexión (Forward+ en la cetrería), para no sumar
		// dos veces la sala
		vec3 envm = min(claw_env_at(rdir, blur_m), vec3(1.8));
		float keep = (1.0 - smoothstep(0.25, 0.7, o.rough)) * o.metal * (1.0 - max(pore, crack_k)) * (1.0 - 0.7 * burn);
		o.emission = envm * fres * keep * 0.4;
		return o;
	}
	if (claw_kind == 4) {
		// polímero (unidad 5p: el acrílico dental y la resina): un dieléctrico con el reflejo de Fresnel de su índice
		// (SPECULAR, de claw_spec) y un cuerpo translúcido de su color: sus pigmentos y cargas difunden una parte de la luz
		// (claw_scatter, el color difuso) y el resto lo atraviesa y sale con lo de detrás, refractado y borroso; lo fino (los
		// bordes, la punta) deja pasar más. Lijado o limado, blanquecino (la superficie rota difunde, como el metacrilato
		// esmerilado); quemado, pardo oscuro y mate
		float thin = 1.0 - smoothstep(0.4, 3.0, r_mm);
		float diff = clamp(claw_scatter * (1.0 - 0.5 * thin), 0.0, 1.0);
		mat3 ivp = mat3(inv_view);
		vec3 nwp = normalize(ivp * n);
		vec3 vinp = -normalize(ivp * v_view);
		vec3 tp = refract(vinp, nwp, 1.0 / claw_ior.g);
		vec3 behind = claw_env_at(dot(tp, tp) > 1e-6 ? tp : vinp, 0.7);
		float frp = claw_fresnel(max(dot(n, v_view), 1e-3), claw_ior.g);
		float sand = clamp(max(frost, smoothstep(0.3, 0.6, o.rough)), 0.0, 1.0);
		vec3 body = mix(claw_base, mix(claw_base, vec3(0.9, 0.89, 0.87), 0.55), sand);
		o.albedo = body * mix(diff, 1.0, sand * 0.7) * (1.0 - 0.1 * edge);
		o.emission = (1.0 - diff) * (1.0 - frp) * (1.0 - sand * 0.7) * behind * claw_base * 0.85;
		o.backlight = 0.3 * (1.0 - diff) + 0.25 * thin;
		float pore = claw_pores * step(0.8, claw_hash21(floor(vec2(s_mm * 5.0, a * 50.0)) + claw_seed));
		o.albedo *= 1.0 - 0.3 * pore;
		o.albedo = mix(o.albedo, vec3(0.03, 0.02, 0.015), crack_k * 0.85);
		o.albedo = mix(o.albedo, claw_char_color, burn * 0.85);
		o.emission *= 1.0 - burn;
		o.rough = mix(o.rough, 0.85, max(burn, pore));
		o.spec = mix(claw_spec, 0.5, burn);
		return o;
	}
	if (claw_kind == 3) {
		// cerámica: blanca difusa, algo translúcida en lo fino; quemada, gris
		float pore = claw_pores * step(0.75, claw_hash21(floor(vec2(s_mm * 5.0, a * 50.0)) + claw_seed));
		o.albedo = claw_base * (1.0 - 0.35 * pore) * (1.0 - 0.1 * edge);
		o.albedo = mix(o.albedo, vec3(0.05), crack_k * 0.8);
		o.albedo = mix(o.albedo, claw_char_color, burn * 0.7);
		o.rough = mix(o.rough, 0.85, max(pore, burn));
		o.backlight = 0.25 * smoothstep(0.0, 1.5, 2.0 - r_mm);
		return o;
	}
	if (claw_kind == 0) {
		// queratina (dibujo, petición 36): las líneas de crecimiento (bandas finas de través que siguen la base, un poco
		// oblicuas e irregulares), las capas del estuche (vetas largas de otro tono, las láminas que se ven bajo la
		// superficie) y las estrías finas a lo largo, en el color y en el relieve; la punta, más fina, algo más clara; la
		// capa de barniz de la queratina pulida por el uso, que la herramienta raya y el calor quema
		vec3 col = claw_base;
		float g = claw_growth;
		float wob = 0.35 * sin(a * 6.2832 * 2.0 + claw_seed) + 0.2 * sin(a * 6.2832 * 5.0 + 1.3);
		// cada detalle se apaga cuando es más fino que un píxel (sin muaré de lejos)
		float ph_l = (s_mm + wob) / 0.55;
		float ph_s = a * 64.0;
		float vis_l = 1.0 - smoothstep(0.3, 0.8, fwidth(ph_l));
		float vis_s = 1.0 - smoothstep(0.3, 0.8, fwidth(ph_s));
		float growth_l = sin(ph_l * 6.2832) * vis_l;
		// bandas anchas de otro tono (de una temporada a otra) y vetas a lo largo: ruido de valor suave, sin escalones
		float xm = s_mm / 1.3 + wob * 0.3;
		float growth_m = mix(claw_hash11(floor(xm) + claw_seed), claw_hash11(floor(xm) + 1.0 + claw_seed), smoothstep(0.0, 1.0, fract(xm))) - 0.5;
		float xa = a * 23.0 + 0.6 * sin(s_mm * 0.21);
		float layer = mix(claw_hash21(vec2(floor(xa), claw_seed)), claw_hash21(vec2(floor(xa) + 1.0, claw_seed)), smoothstep(0.2, 0.8, fract(xa))) - 0.5;
		float stri = sin(ph_s * 6.2832 + 0.8 * sin(s_mm * 0.9)) * (0.6 + 0.4 * claw_hash11(floor(ph_s) + 3.0)) * vis_s;
		col *= 1.0 + g * (0.015 * growth_l + 0.08 * growth_m + 0.1 * layer + 0.02 * stri);
		// la punta, más fina, algo más clara
		float tipk = smoothstep(apex_mm - 4.0, apex_mm, s_mm) * g;
		col = mix(col, col * 1.25 + vec3(0.012, 0.01, 0.008), tipk * 0.45);
		// limada: el polvo blanquecino de la queratina rota en los surcos (más cuanto más rugosa)
		float dusty = smoothstep(0.3, 0.6, o.rough) * g;
		col = mix(col, col * 0.7 + vec3(0.16, 0.15, 0.13), dusty * 0.5);
		// quemada: se oscurece hacia el carbón y pierde el brillo
		col = mix(col, claw_char_color, burn * 0.9);
		o.rough = mix(o.rough, 0.85, burn);
		// en el relieve, apenas: la queratina pulida por el uso es lisa (la referencia de la petición 36)
		o.normal = normalize(o.normal + (ta * stri * 0.018 + ts * growth_l * 0.005) * g);
		o.albedo = col * (1.0 - 0.2 * edge);
		o.albedo = mix(o.albedo, vec3(0.015, 0.012, 0.01), crack_k);
		o.backlight = 0.12 * (1.0 - burn);
		o.clearcoat = claw_clearcoat * (1.0 - smoothstep(0.25, 0.5, o.rough)) * (1.0 - burn);
		return o;
	}
	// gema o vidrio
	mat3 iv = mat3(inv_view);
	vec3 nw = normalize(iv * n);
	vec3 vw = normalize(iv * v_view);
	vec3 v_in = -vw;
	float cos_i = max(dot(n, v_view), 1e-3);
	// las caras de dentro (dibujo de la talla): la de atrás, inclinada respecto a la opuesta como el pabellón de una gema
	// tallada (~38°, con la variación de cada faceta; ~12° en una garra lisa, solo por su curva), y la de delante por la
	// que vuelve a salir tras rebotar, como la corona (~30°). Con esa inclinación decide la física: los índices altos
	// (diamante, moissanita, circonita: ángulo crítico de 22-28°) rebotan casi toda la luz y brillan; los bajos (cuarzo,
	// vidrio: ~40°) dejan escapar parte por detrás y se ve a través («ventana»)
	vec2 fc = vec2(a * max(claw_facets, 1.0), s_mm / claw_facet_len(apex_mm));
	float jb = claw_hash21(vec2(floor(fc.x) + 17.0, floor(fc.y) + claw_seed));
	vec3 tw = normalize(iv * ts);
	vec3 aw = normalize(iv * ta);
	bool cut = claw_facets > 2.5;
	// el mosaico de la talla (dibujo, unidad 5p): por cada faceta de delante se ven varias de atrás, como en una gema
	// tallada (2 × 2 rectángulos partidos en triángulos, cada uno con su inclinación): más caminos dentro, más puntos de
	// luz que alcanzar y más destellos. De lejos, cuando un triángulo ocupa menos de un par de píxeles, se queda la faceta
	// entera (sin centelleo de muestreo)
	float js = 0.5;
	float mos = 0.0;
	if (cut && claw_uv_mode == 0) {
		vec2 q = fc * 2.0;
		vec2 qi = floor(q);
		vec2 qf = q - qi;
		float tri = mod(qi.x + qi.y, 2.0) < 0.5 ? step(qf.y, qf.x) : step(1.0, qf.x + qf.y);
		js = claw_hash21(qi * vec2(1.0, 1.7) + vec2(tri * 5.0 + 3.0, claw_seed * 3.0));
		mos = 1.0 - smoothstep(0.35, 0.8, max(fwidth(q.x), fwidth(q.y)));
	}
	float pav = radians(cut ? 38.0 + (jb - 0.5) * 16.0 + (js - 0.5) * 14.0 * mos : 12.0);
	float az = jb * 6.2831853 * 3.0 + (js - 0.5) * 2.6 * mos;
	// en una talla, las caras de dentro son planas (unidad 5p): su marco sale de la normal de la faceta, ya plana, y no de
	// las tangentes de la superficie lisa, que giran con la curva de la garra (con ellas, las caras de dentro quedaban
	// curvas y un punto de luz solo encendía un píxel); la base ortonormal sin ramas de Duff et al. (2017)
	vec3 fx = tw;
	vec3 fy = aw;
	if (cut) {
		float sgn = nw.z >= 0.0 ? 1.0 : -1.0;
		float ka = -1.0 / (sgn + nw.z);
		float kb = nw.x * nw.y * ka;
		fx = vec3(1.0 + sgn * nw.x * nw.x * ka, sgn * kb, -sgn * nw.x);
		fy = vec3(kb, sgn + nw.y * nw.y * ka, -nw.y);
	}
	vec3 pdir = normalize(fx * cos(az) + fy * sin(az));
	vec3 nb = normalize(-nw * cos(pav) + pdir * sin(pav));
	float crown = radians(cut ? 30.0 + (claw_hash11(jb * 37.0) - 0.5) * 12.0 + (0.5 - js) * 10.0 * mos : 10.0);
	float az2 = az + 2.3;
	vec3 nf2 = normalize(nw * cos(crown) + normalize(fx * cos(az2) + fy * sin(az2)) * sin(crown));
	// (con claw_section_k = 1 no se toca r_mm: el mismo resultado al bit que antes, en cualquier GPU)
	float r_abs = claw_section_k > 1.0 ? r_mm / sqrt(claw_section_k) : r_mm;
	float thick = max(2.0 * (claw_uv_mode == 0 ? r_abs : claw_thick_mm * 0.5), 0.2);
	float blur = clamp(frost + o.rough * 0.8, 0.0, 1.0);
	bool second = claw_quality == 0;
	vec3 inside = vec3(0.0);
	int rays = (claw_quality == 0 && abs(claw_ior_e.g - claw_ior.g) > 1e-4) ? 2 : 1;
	for (int c = 0; c < 3; c++) {
		float acc = 0.0;
		for (int k = 0; k < 2; k++) {
			if (k >= rays) {
				break;
			}
			float ior = k == 0 ? claw_ior[c] : claw_ior_e[c];
			float fr = claw_fresnel(cos_i, ior);
			vec4 tr = claw_trace(v_in, nw, nb, nf2, ior, second);
			vec3 envc = claw_env_at(tr.xyz, blur);
			if (claw_env > 0.5) {
				envc = mix(envc, vec3(dot(envc, vec3(0.2126, 0.7152, 0.0722))) * 1.15, claw_road_neutral);
				float sg = max(dot(normalize(tr.xyz), normalize(claw_road_sun_dir)), 0.0);
				envc += claw_road_sun_color * (pow(sg, 48.0) * claw_road_gem_sun + pow(sg, 8.0) * claw_road_gem_sun * 0.04);
			}
			envc += claw_env_spots(normalize(tr.xyz), blur, 1.0);
			float lc = envc[c];
			// por detrás, lo que hay en la pantalla (refractado), para el rayo que sale de un solo paso
			if (has_screen && tr.w > 0.5 && tr.w < 1.5) {
				lc = mix(lc, screen_behind[c][c], 0.75);
			}
			float path = thick * max(tr.w, 0.6) * 0.5 / max(cos_i, 0.35);
			float trans = exp(-claw_absorb[c] * path) * claw_tint[c];
			acc += (1.0 - fr) * lc * trans;
		}
		inside[c] = acc / float(rays);
	}
	// lo esmerilado difunde: blanco lechoso con el color de la gema
	vec3 body = exp(-claw_absorb * thick * 0.5) * claw_tint;
	vec3 milky = body * claw_env_at(nw, 1.0) * 0.5;
	o.emission = mix(inside, milky, clamp(frost, 0.0, 1.0));
	o.albedo = body * 0.05 * clamp(frost, 0.0, 1.0);
	// grietas: un plano que refleja dentro (una línea brillante)
	o.emission = mix(o.emission, claw_env_at(reflect(v_in, nw), 0.2) * 0.9, crack_k * 0.7);
	// lo quemado en la cetrería: hollín de la queratina y del pegamento encima de la gema, que la oscurece y la apaga (a
	// ~230 °C ninguna gema cambia; el diamante solo se graba al aire por encima de ~600 °C, en la reforja: «oxidado»)
	o.emission = mix(o.emission, o.emission * 0.15, burn);
	o.albedo = mix(o.albedo, claw_char_color, burn * 0.85);
	o.emission = mix(o.emission, milky * 0.8, claw_oxide);
	o.rough = mix(o.rough, 0.6, max(frost * 0.6, max(burn, claw_oxide)));
	o.spec = mix(claw_spec, 0.5, max(frost * 0.3, burn));
	o.spec = min(o.spec + claw_clear * 0.2, 1.0);
	o.emission *= 1.0 - 0.05 * edge;
	return o;
}

// Tangentes a lo largo (s) y alrededor (a) en el espacio de la vista, de las derivadas en la pantalla, sin datos de la
// malla: dp/ds y dp/da, resolviendo el jacobiano de (s, a) en la pantalla (unidad 5p). Así van en el sentido en que
// crecen s y a con cualquier renderizador: con el marco de Schüler (2013, «Normal mapping without precomputed tangents»),
// las dos cambiaban de signo cuando la y de la pantalla va al revés (de OpenGL a Vulkan) y las facetas de una talla se
// curvaban. Sin el salto de a en la costura de la vuelta (claw_da). Si s no cambia (uv_mode 1, otra malla), el de Schüler.
void claw_tangents(vec3 n, vec3 p, vec2 uv, out vec3 ts, out vec3 ta) {
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 duv1 = vec2(dFdx(uv.x), claw_da(dFdx(uv.y)));
	vec2 duv2 = vec2(dFdy(uv.x), claw_da(dFdy(uv.y)));
	float det = duv1.x * duv2.y - duv2.x * duv1.y;
	if (abs(det) > 1e-14) {
		ts = (dp1 * duv2.y - dp2 * duv1.y) / det;
		ta = (dp2 * duv1.x - dp1 * duv2.x) / det;
	} else {
		vec3 dp2p = cross(dp2, n);
		vec3 dp1p = cross(n, dp1);
		ts = dp2p * duv1.x + dp1p * duv2.x;
		ta = dp2p * duv1.y + dp1p * duv2.y;
	}
	ts = dot(ts, ts) > 1e-20 ? normalize(ts - n * dot(ts, n)) : normalize(cross(n, vec3(0.0, 1.0, 0.0)) + vec3(1e-4));
	ta = dot(ta, ta) > 1e-20 ? normalize(ta - n * dot(ta, n)) : normalize(cross(ts, n));
}
