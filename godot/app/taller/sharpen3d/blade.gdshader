// Acero de la herramienta que se afila (hoja, broca o fresa): bisel, acabado, colores de revenido, incandescencia.
// - Hojas (use_bevel): la malla trae cada vértice en la línea media con CUSTOM0 = (d: distancia al filo en m, lado
//   ±1, semiespesor del cuerpo en m, su pendiente) y aquí se le da el espesor con el bisel del ángulo pedido
//   (bevel.gdshaderinc). Brocas y fresas traen ya la forma final y UV2.x = 1 en la cara tallada.
// - Temperatura: textura RG16F con °C/1000: R, la de ahora; G, el pico que ha alcanzado cada punto. Sin temp_2d, una
//   fila a lo largo del filo (edge_temp_c y edge_peak_c de set_state) y cae hacia el lomo con tint_len (dibujo); con
//   temp_2d, también el perfil hacia el lomo, en escala logarítmica.
// - Colores de revenido: rampa que da la escena con la tabla del core (edge_thermal.gd), con el pico (la capa de óxido
//   se queda al enfriarse); aquí solo se pintan.
// - Incandescencia: rampa de sparks.gd (TM 9-237, tabla V) con la temperatura de ahora, por encima de ≈450 °C.
// UV: x = posición a lo largo del filo (0 talón · 1 punta; en brocas y fresas, radio relativo). UV2.y: 0 cara, 1 tapa
// (lomo, talón: conserva su normal), 2 punta tallada (normal de faceta).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://app/taller/sharpen3d/bevel.gdshaderinc"

uniform bool use_bevel = true;
uniform vec3 steel_color : source_color = vec3(0.64, 0.65, 0.67);
uniform float steel_rough = 0.3;
uniform float ground_rough = 0.4;
uniform float steel_metallic = 0.78;  // < 1: parte difusa para que la hoja no sea solo el reflejo del taller
uniform float scratch_per_m = 9000.0;   // rayas del amolado por metro de filo (dibujo)
uniform sampler2D edge_temp : filter_linear, repeat_disable;
uniform bool temp_2d = false;
uniform float tint_len = 0.0015;
uniform float temp_d0 = 0.00005;
uniform float temp_dmax = 0.03;
uniform sampler2D temper_ramp : source_color, filter_linear, repeat_disable;
uniform float ramp_min_c = 150.0;
uniform float ramp_max_c = 450.0;
uniform sampler2D heat_ramp : source_color, filter_linear, repeat_disable;
uniform float ambient_c = 20.0;

varying float v_u;
varying float v_d;
varying float v_ground;
varying float v_flat;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	v_u = UV.x;
	v_d = CUSTOM0.x;
	v_flat = UV2.y > 1.5 ? 1.0 : 0.0;
	v_ground = UV2.x;
	if (use_bevel) {
		vec3 f = blade_face(CUSTOM0.x, CUSTOM0.y, CUSTOM0.z, CUSTOM0.w);
		VERTEX.z = f.x;
		v_ground = f.z;
		if (UV2.y < 0.5) {
			NORMAL = normalize(vec3(0.0, -f.y, CUSTOM0.y));
		}
	}
}

void fragment() {
	if (v_flat > 0.5) {
		vec3 gn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		NORMAL = dot(gn, NORMAL) < 0.0 ? -gn : gn;
	}
	bool ground = v_ground > 0.5;
	vec3 col = steel_color;
	float rough = steel_rough;
	if (ground) {
		// Rayado fino del amolado, a través del bisel (la muela pasa del lomo al filo)
		col *= 0.88 + 0.16 * hash11(floor(v_u * scratch_per_m));
		rough = ground_rough;
	} else {
		col *= 0.97 + 0.05 * hash11(floor(v_d * 20000.0) + 7.0);
	}
	vec2 tt;  // (ahora, pico) en °C
	if (temp_2d) {
		float vv = log(1.0 + v_d / temp_d0) / log(1.0 + temp_dmax / temp_d0);
		tt = texture(edge_temp, vec2(v_u, clamp(vv, 0.0, 1.0))).rg * 1000.0;
	} else {
		vec2 te = texture(edge_temp, vec2(v_u, 0.5)).rg * 1000.0;
		tt = ambient_c + (te - ambient_c) * exp(-max(v_d, 0.0) / max(tint_len, 1e-5));
	}
	vec4 tc = texture(temper_ramp, vec2(clamp((tt.y - ramp_min_c) / max(ramp_max_c - ramp_min_c, 1.0), 0.0, 1.0), 0.5));
	col = mix(col, tc.rgb, tc.a * 0.85);
	vec3 glow = texture(heat_ramp, vec2(clamp((tt.x - 300.0) / 1000.0, 0.0, 1.0), 0.5)).rgb;
	ALBEDO = col;
	METALLIC = mix(steel_metallic, 0.5, tc.a);
	ROUGHNESS = rough;
	EMISSION = glow * smoothstep(450.0, 760.0, tt.x) * 2.5;
}
