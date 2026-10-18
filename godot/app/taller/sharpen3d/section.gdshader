// Sección de la hoja en la vista «seccion»: una tira plana (en el plano perpendicular al filo, en el punto de
// contacto) a la que el vértice da el mismo espesor que a la hoja 3D (bevel.gdshaderinc), con el rayado a 45° de un
// plano técnico. El cuerpo es lineal cerca del filo: semiespesor sec_hb0 + sec_slope·d (hasta sec_hmax), de la
// herramienta en ese punto. CUSTOM0 = (d en m, lado ±1). Sin luz, para que se lea como un dibujo.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://app/taller/sharpen3d/bevel.gdshaderinc"

uniform vec3 fill_color : source_color = vec3(0.74, 0.76, 0.8);
uniform vec3 hatch_color : source_color = vec3(0.3, 0.32, 0.38);
uniform vec3 ground_color : source_color = vec3(0.9, 0.75, 0.45);
uniform float hatch_m = 0.00025;    // separación del rayado (m de escena)
uniform float sec_hb0 = 0.000175;   // m: semiespesor del cuerpo en el vértice (sin bisel)
uniform float sec_slope = 0.024;    // pendiente del semiespesor del cuerpo
uniform float sec_hmax = 0.00125;   // m: semiespesor en el lomo

varying vec2 v_p;
varying float v_ground;

void vertex() {
	float d = CUSTOM0.x;
	float hb = min(sec_hb0 + sec_slope * d, sec_hmax);
	float hbs = sec_hb0 + sec_slope * d < sec_hmax ? sec_slope : 0.0;
	vec3 f = blade_face(d, CUSTOM0.y, hb, hbs);
	VERTEX.z = f.x;
	v_ground = f.z;
	v_p = VERTEX.yz;
}

void fragment() {
	float h = step(0.55, fract((v_p.x + v_p.y) / hatch_m));
	vec3 base = mix(fill_color, ground_color, step(0.5, v_ground) * 0.35);
	ALBEDO = mix(base, hatch_color, h * 0.6);
}
