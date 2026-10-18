// Ojo de los animales (unidad 4l): un globo con la córnea brillante. UV.y va de atrás (0) al polo de delante (1): el
// iris y la pupila se pintan alrededor del polo (iris_r y pupil_r, en esa escala), con el anillo oscuro del borde del
// iris; pupil_sx < 1 la estrecha en vertical (el tigre al sol). Un reflejo fijo (la ventana del cielo) le da vida desde
// cualquier ángulo. Solo dibujo.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 iris : source_color = vec4(0.8, 0.5, 0.1, 1.0);
uniform vec4 sclera : source_color = vec4(0.9, 0.86, 0.78, 1.0);
uniform float iris_r = 0.55;
uniform float pupil_r = 0.25;
uniform float pupil_sx = 1.0;
uniform float fade = 1.0;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	if (fade < 0.999 && bayer4(FRAGCOORD.xy) >= fade) {
		discard;
	}
	float r = 1.0 - UV.y;
	float a = UV.x * 6.2831853;
	vec2 q = vec2(cos(a), sin(a)) * r;
	float rp = length(vec2(q.x / max(pupil_sx, 0.05), q.y));
	vec3 c = sclera.rgb;
	float ring = smoothstep(iris_r * 0.78, iris_r, r);
	vec3 ic = mix(iris.rgb * 1.15, iris.rgb * 0.45, ring);
	c = mix(ic, c, smoothstep(iris_r, iris_r + 0.04, r));
	c = mix(vec3(0.015), c, smoothstep(pupil_r - 0.02, pupil_r + 0.02, rp));
	ALBEDO = c;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	float glint = smoothstep(0.972, 0.99, dot(NORMAL, normalize(vec3(-0.35, 0.55, 0.76))));
	EMISSION = vec3(0.9) * glint;
}
