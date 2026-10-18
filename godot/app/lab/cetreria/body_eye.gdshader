// Cetrería · el ojo de los cuerpos en alta definición (unidad 5i, petición 37; dibujo hecho en código): el globo en su marco
// (+Z hacia donde mira), con el iris de fibras radiales y su anillo oscuro, la pupila (redonda, o en rendija en el de
// película) y la córnea húmeda que brilla con las luces de la sala (rugosidad muy baja y capa de barniz donde el
// renderizador la tiene). Con la anestesia, la pupila se dilata (pupil_open).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 iris_color : source_color = vec3(0.85, 0.62, 0.15);
uniform vec3 iris_dark : source_color = vec3(0.35, 0.2, 0.05);
uniform vec3 sclera_color : source_color = vec3(0.86, 0.82, 0.74);
uniform float iris_r = 0.72;
uniform float pupil_r = 0.36;
uniform float slit = 0.0;
uniform float pupil_open = 0.0;

varying vec3 v_p;

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void vertex() {
	v_p = VERTEX;
}

void fragment() {
	vec3 q = normalize(v_p);
	float r = length(q.xy);
	float ri = r / iris_r;
	vec3 col = sclera_color * (0.75 + 0.25 * smoothstep(-0.2, 0.6, q.z));
	if (q.z > 0.0 && ri < 1.04) {
		float ang = atan(q.y, q.x);
		float k = floor(ang * 9.0);
		float fib = 0.5 + 0.5 * sin(ang * 61.0 + 3.0 * hash11(k)) * (0.6 + 0.4 * sin(ri * 18.0 + hash11(k + 3.0) * 6.0));
		vec3 ic = mix(iris_color, iris_dark, clamp(smoothstep(0.7, 1.0, ri) * 0.85 + 0.25 * (1.0 - fib) * smoothstep(0.2, 0.9, ri), 0.0, 1.0));
		ic = mix(ic, iris_color * 1.25, (1.0 - smoothstep(0.0, 0.45, abs(ri - 0.45))) * 0.25 * fib);
		col = mix(ic, col, smoothstep(0.98, 1.04, ri));
		float pr = clamp(pupil_r * (1.0 + 1.1 * pupil_open), 0.05, 0.92);
		float pd = slit > 0.5 ? length(vec2(q.x / (pr * mix(0.22, 0.8, pupil_open)), q.y / (pr * 1.25))) / iris_r : ri / pr;
		col = mix(vec3(0.008, 0.007, 0.007), col, smoothstep(0.9, 1.02, pd));
	}
	ALBEDO = col;
	ROUGHNESS = 0.035;
	SPECULAR = 0.85;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
