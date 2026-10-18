// Pintura del turismo del coche en marcha (unidad 4k): la chapa pintada con su barniz, las juntas de los paneles y los
// daños en el propio material (car_damage.gdshaderinc): la abolladura hunde la malla y deforma el reflejo, los surcos
// enseñan la capa a la que llegan (Data.PAINT_LAYERS: barniz, color, imprimación y anticorrosivo, y la carrocería debajo)
// y los agujeros y las ranuras dejan ver lo oscuro de detrás.
// La cara de dentro (la que se ve por las lunas) es el interior oscuro.
// Aspecto por carrocería (car_model.gd: STYLES): metalizada con barniz (acero moderno y aluminio), sólida (clásico) y, en
// el coche de plástico, la aleta y los paragolpes de termoplástico, pintados con otro brillo (plastic_parts).
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://app/lab/car3d/car_damage.gdshaderinc"

uniform vec3 paint_color : source_color = vec3(0.49, 0.17, 0.23);
uniform float paint_metallic = 0.45;
uniform float paint_rough = 0.32;
uniform float coat = 1.0;
uniform float coat_rough = 0.05;
uniform vec3 interior_color : source_color = vec3(0.028, 0.028, 0.032);
// Colores de las capas (lineales): barniz, color, imprimación, anticorrosivo o promotor, carrocería y el hueco.
uniform vec4 layer_col[6];
uniform float body_metal = 1.0;
// Coche de plástico: aleta y paragolpes de termoplástico pintado (otro brillo y un matiz algo distinto).
uniform float plastic_parts = 0.0;
uniform vec3 plastic_shift : source_color = vec3(0.97, 0.95, 0.9);
uniform float plastic_rough = 0.42;
// Juntas de los paneles: segmentos (x0, v0, x1, v1) y (eje, en los dos costados, holgura m, 0); tapa del depósito
// (x, y, radio, 1 si la hay) en el costado de +z.
const int MAX_SEAMS = 16;
uniform int n_seams = 0;
uniform vec4 seam_ab[MAX_SEAMS];
uniform vec4 seam_p[MAX_SEAMS];
uniform vec4 fuel_flap = vec4(0.0);
// Zonas del coche de plástico: la aleta (x0, x1, y máx.) y los paragolpes (x del de atrás, x del de delante, y máx.).
uniform vec3 fender_zone = vec3(3.10, 4.40, 0.97);
uniform vec3 bumper_zone = vec3(0.22, 4.28, 0.62);

// Unidad 4s: lo que se inclina la normal en una abolladura, en fracciones de su pendiente de verdad (dibujo). Con la pendiente
// entera, la chapa abollada miraba hacia la carretera y el interior oscuro y se veía como un agujero negro; con algo menos
// se lee la chapa doblada, con su reflejo deformado (la hondura de la malla es la de la física).
const float DENT_SHADE = 0.55;

varying vec3 v_obj;
varying vec3 v_objn;

void vertex() {
	vec3 disp;
	vec3 grad;
	v_obj = VERTEX;
	v_objn = NORMAL;
	if (n_dents > 0) {
		dent_field(VERTEX, disp, grad);
		VERTEX += disp;
		NORMAL = normalize(NORMAL + grad * DENT_SHADE);
	}
}

float seams(vec3 p, vec3 n, float px) {
	float cov = 0.0;
	for (int i = 0; i < MAX_SEAMS; i++) {
		if (i >= n_seams) {
			break;
		}
		vec4 sp = seam_p[i];
		int axis = int(sp.x + 0.5);
		vec3 q = p;
		vec3 nn = n;
		if (sp.y > 0.5) {
			// en los dos costados (o a los dos lados del eje): se mira la mitad de +z
			q.z = abs(q.z);
			nn.z = abs(nn.z);
		}
		if (dot(nn, dmg_axis(axis)) < 0.4) {
			continue;
		}
		float d = dmg_seg(dmg_plane(q, axis), seam_ab[i].xy, seam_ab[i].zw);
		float w = max(sp.z * 0.5, px * 0.5);
		cov = max(cov, (1.0 - smoothstep(w - px * 0.5, w + px * 0.5, d)) * clamp(0.5 + sp.z * 0.5 / max(w, 1e-6), 0.5, 1.0));
	}
	if (fuel_flap.w > 0.5 && n.z > 0.4) {
		float d = abs(length(p.xy - fuel_flap.xy) - fuel_flap.z);
		float w = max(0.0018, px * 0.5);
		cov = max(cov, (1.0 - smoothstep(w - px * 0.5, w + px * 0.5, d)) * 0.8);
	}
	return cov;
}

void fragment() {
	if (!FRONT_FACING) {
		ALBEDO = interior_color;
		METALLIC = 0.0;
		ROUGHNESS = 0.9;
	} else {
		vec3 nobj = normalize(v_objn);
		if (n_dents > 0) {
			vec3 disp;
			vec3 grad;
			dent_field(v_obj, disp, grad);
			nobj = normalize(v_objn + grad * DENT_SHADE);
			NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * nobj));
		}
		float px = max(length(fwidth(v_obj)) * 0.7, 1e-5);
		vec3 base = paint_color;
		float met = paint_metallic;
		float rough = paint_rough;
		float cc = coat;
		float ccr = coat_rough;
		if (plastic_parts > 0.5) {
			bool fender = abs(nobj.z) > 0.3 && v_obj.x > fender_zone.x && v_obj.x < fender_zone.y && v_obj.y < fender_zone.z;
			bool bumper = v_obj.y < bumper_zone.z && (v_obj.x < bumper_zone.x || v_obj.x > bumper_zone.y);
			if (fender || bumper) {
				base *= plastic_shift;
				met = 0.0;
				rough = plastic_rough;
				cc = 0.55;
				ccr = 0.12;
			}
		}
		// juntas: la holgura oscura entre paneles
		float sc = seams(v_obj, nobj, px);
		base = mix(base, vec3(0.012), sc * 0.9);
		cc *= 1.0 - sc;
		// daños: surcos, ranuras, punzadas y agujeros, con su relieve (la normal de las paredes y de los labios, y la
		// oclusión del fondo: unidad 4s)
		vec4 relief;
		float lip;
		vec4 m = damage_marks_ex(v_obj, nobj, px, relief, lip);
		if (dot(relief.xyz, relief.xyz) > 1e-8) {
			vec3 nb = normalize(nobj + relief.xyz);
			NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * nb));
		}
		if (m.x > 0.001) {
			int layer = int(m.y + 0.5);
			vec3 col = base;
			float lmet = met;
			float lrough = 0.7;
			float lcc = 0.0;
			if (layer == 0) {
				// solo el barniz: una raya clara (el barniz rayado dispersa la luz)
				col = mix(base, layer_col[0].rgb, 0.6);
				lmet = met * 0.4;
				lrough = 0.55;
				lcc = 0.25;
			} else if (layer == 1) {
				// el color sin barniz: mate, con el pigmento a la vista
				col = base * 1.12;
				lrough = 0.75;
			} else if (layer == 2 || layer == 3) {
				col = layer_col[layer].rgb;
				lmet = 0.0;
				lrough = 0.8;
			} else if (layer == 4) {
				// la carrocería a la vista: el metal recién cortado brilla (sus paredes reflejan la luz de todas partes)
				col = layer_col[4].rgb * (body_metal > 0.5 ? 1.25 : 1.0);
				lmet = body_metal * 0.95;
				lrough = body_metal > 0.5 ? 0.22 : 0.45;
				if (m.z > 0.5 && body_metal < 0.5) {
					col = mix(col, vec3(0.78, 0.78, 0.76), 0.55);  // plástico desgarrado: el labio se blanquea
				}
			} else {
				// el hueco de lado a lado: lo de detrás, a la sombra (unidad 4s: con la luz del primer plano se veía gris)
				col = layer_col[5].rgb * 0.25;
				lmet = 0.0;
				lrough = 1.0;
			}
			base = mix(base, col, m.x);
			met = mix(met, lmet, m.x);
			rough = mix(rough, lrough, m.x);
			cc = mix(cc, lcc, m.x);
		}
		// el labio levantado: la pintura estirada y el barniz cuarteado brillan algo menos y se aclaran (dibujo)
		if (lip > 0.001) {
			base = mix(base, base * 1.18 + vec3(0.02), lip * 0.6);
			cc *= 1.0 - 0.5 * lip;
		}
		base *= 1.0 - m.w;
		base *= relief.w;
		AO = relief.w;
		AO_LIGHT_AFFECT = 0.6;
		ALBEDO = base;
		METALLIC = met;
		ROUGHNESS = rough;
		CLEARCOAT = cc;
		CLEARCOAT_ROUGHNESS = ccr;
	}
}
