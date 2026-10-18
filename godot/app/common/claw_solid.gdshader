// Garra opaca de la biblioteca de materiales (unidad 5e): metales, el mineral opaco, la cerámica, la queratina del
// coche en marcha y de la galería y, en el preset del teléfono, las gemas (sin leer la pantalla: lo de detrás lo pone el
// entorno). El modelo está en claw_material.gdshaderinc. Un mismo material sirve a muchas garras (el largo de cada una
// va en su malla, UV2.y); el desvanecido, con un tramado ordenado como el de los animales (animal_surface.gdshader).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://app/common/claw_material.gdshaderinc"

uniform float claw_apex_mm = 30.0;
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
	vec3 none[3] = vec3[3](vec3(0.0), vec3(0.0), vec3(0.0));
	ClawOut o = claw_shade(n, VIEW, ts, ta, s_mm, a, r_mm, apex, INV_VIEW_MATRIX, none, false);
	NORMAL = o.normal;
	ALBEDO = o.albedo;
	EMISSION = o.emission;
	ROUGHNESS = o.rough;
	METALLIC = o.metal;
	SPECULAR = o.spec;
	BACKLIGHT = o.albedo * o.backlight;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = claw_clearcoat_rough;
}
