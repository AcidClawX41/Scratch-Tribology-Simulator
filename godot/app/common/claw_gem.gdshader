// Garra de gema o de vidrio de la biblioteca de materiales (unidad 5e), en el escritorio: como claw_solid.gdshader, pero
// lo que sale por la cara de atrás es lo que hay detrás en la pantalla, refractado con el índice de cada canal (se ve a
// través y con los bordes de color de la dispersión). Leer la pantalla funciona en los tres renderizadores (comprobado en
// Compatibility); el teléfono usa claw_solid.gdshader, sin esa copia de la pantalla.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://app/common/claw_material.gdshaderinc"

uniform float claw_apex_mm = 30.0;
uniform sampler2D claw_screen : hint_screen_texture, filter_linear_mipmap;
// el desvanecido (tramado): un uniforme del material, no de cada malla (los instance uniform reservan 16 huecos por
// malla en un búfer de 4096 en Compatibility, y un animal del coche lleva decenas de trozos de garra); quien desvanece
// una garra usa su propia copia del material (Animal3D)
uniform float claw_fade = 1.0;

float claw_bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	if (claw_fade < 0.999 && claw_bayer4(FRAGCOORD.xy) >= claw_fade) {
		discard;
	}
	vec3 n = normalize(NORMAL);
	float s_mm = claw_uv_mode == 0 ? UV.x : 0.0;
	float a = claw_uv_mode == 0 ? UV.y : UV.x;
	float r_mm = claw_uv_mode == 0 ? UV2.x : claw_thick_mm * 0.5;
	// dónde acaba la garra (mm): el de la malla (UV2.y, el largo de cada garra de ClawGeo) o el del material
	float apex = claw_uv_mode == 0 && UV2.y > 0.0 ? UV2.y : claw_apex_mm;
	vec3 ts;
	vec3 ta;
	claw_tangents(n, VERTEX, vec2(s_mm, a), ts, ta);
	// lo de detrás, por canal: el desvío de la refracción de cada índice (dibujo: el desvío en la pantalla crece con el
	// espesor y con lo que se tuerce el rayo); más borroso cuanto más rugosa o esmerilada la superficie
	float lod = clamp((claw_rough + claw_frost) * 7.0, 0.0, 6.0);
	vec3 behind[3];
	for (int c = 0; c < 3; c++) {
		vec3 t = refract(-VIEW, n, 1.0 / claw_ior[c]);
		vec2 off = (t.xy + VIEW.xy) * 0.06 * clamp(r_mm / 3.0, 0.3, 2.0);
		behind[c] = textureLod(claw_screen, clamp(SCREEN_UV + off, vec2(0.001), vec2(0.999)), lod).rgb;
	}
	ClawOut o = claw_shade(n, VIEW, ts, ta, s_mm, a, r_mm, apex, INV_VIEW_MATRIX, behind, true);
	NORMAL = o.normal;
	ALBEDO = o.albedo;
	EMISSION = o.emission;
	ROUGHNESS = o.rough;
	METALLIC = o.metal;
	SPECULAR = o.spec;
}
