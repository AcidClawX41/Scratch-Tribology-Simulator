// Partículas del viento del coche en marcha (unidad 4k): cada instancia es una estela corta que avanza por su línea de
// corriente (air_flow.gd la guarda muestreada en «paths», a pasos iguales de recorrido del aire libre, así que donde el
// aire va más deprisa las muestras están más separadas y la partícula corre más). La estela es por dónde ha pasado la
// partícula en el último momento (trail, en recorrido del aire libre): sigue la curva y es más larga donde el aire va más
// deprisa, como un trazo con desenfoque de movimiento.
// Datos por instancia (INSTANCE_CUSTOM): la línea, su desfase (0-1), su carril en z (m) y su grosor relativo.
// Solo dibujo: ilustra la velocidad local del modelo (v·√(1 − Cp) de las zonas de MovingCar.ZONES); no es una
// simulación del flujo.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D paths : filter_nearest, repeat_disable;
uniform int samples = 192;
uniform float travel = 0.0;
uniform float trail = 0.2;
uniform float flow_sign = 1.0;
uniform float cross_tan = 0.0;
uniform float x_in = 6.9;
uniform float x_out = -3.4;
uniform float width_m = 0.012;
uniform float alpha = 0.5;
uniform vec3 color : source_color = vec3(0.7, 0.72, 0.8);
uniform vec3 color_fast : source_color = vec3(0.9, 0.97, 1.0);
uniform vec3 color_near : source_color = vec3(1.0, 0.55, 0.7);
uniform vec4 focus = vec4(0.0, 0.0, 0.0, -1.0);

varying float v_a;
varying float v_fast;
varying float v_near;

vec4 path_at(int row, float tau, float total) {
	float fi = clamp(tau / total, 0.0, 1.0) * float(samples - 1);
	int i0 = int(floor(fi));
	int i1 = min(i0 + 1, samples - 1);
	return mix(texelFetch(paths, ivec2(i0, row), 0), texelFetch(paths, ivec2(i1, row), 0), fi - float(i0));
}

void vertex() {
	int row = int(INSTANCE_CUSTOM.r + 0.5);
	vec4 info = texelFetch(paths, ivec2(samples, row), 0);
	float total = max(info.r, 0.001);
	float head = fract(INSTANCE_CUSTOM.g + travel / total) * total;
	float t = VERTEX.x;
	float tau = head - flow_sign * t * trail;
	float valid = step(0.0, tau) * step(tau, total);
	tau = clamp(tau, 0.0, total);
	vec4 s = path_at(row, tau, total);
	vec4 s2 = path_at(row, min(tau + total / float(samples), total), total);
	vec2 d = s2.xy - s.xy;
	d = length(d) > 1e-6 ? normalize(d) : vec2(-1.0, 0.0);
	vec3 pos = vec3(s.xy, s.z + INSTANCE_CUSTOM.b);
	float traveled = flow_sign > 0.0 ? (x_in - pos.x) : (pos.x - x_out);
	pos.z += traveled * cross_tan;
	pos.xy += vec2(-d.y, d.x) * VERTEX.y * width_m * INSTANCE_CUSTOM.a;
	VERTEX = pos;
	float u = head / total;
	float ends = smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.9, 1.0, u));
	v_a = alpha * pow(1.0 - t, 1.4) * ends * valid;
	v_fast = clamp((s.w - 1.0) * 5.0, -1.0, 1.0);
	v_near = focus.w > 0.0 ? 1.0 - smoothstep(focus.w * 0.55, focus.w, distance(pos, focus.xyz)) : 0.0;
}

void fragment() {
	vec3 c = mix(color, color_fast, max(v_fast, 0.0));
	c *= 1.0 + min(v_fast, 0.0) * 0.45;
	c = mix(c, color_near, v_near);
	ALBEDO = c;
	ALPHA = v_a;
}
