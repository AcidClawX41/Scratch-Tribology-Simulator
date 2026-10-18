// Las montañas de fondo del coche en marcha (unidad 4x, scenery.gd): dos anillos de siluetas alrededor de la cámara (la
// cercana más oscura y verdosa, la lejana más azulada y clara, la perspectiva aérea), que giran al revés que el coche en la
// curva (están en el mundo, como el sol de la 4w) y casi no se mueven con la cámara (se ponen donde está ella). Sin luz
// propia ni niebla: su color ya es el de la lejanía, con el lado al sol algo más claro y la nieve de las cumbres altas de la
// capa lejana. Solo dibujo. Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

uniform float heading = 0.0;  // lo que ha girado el coche (rad, + a la izquierda)
uniform vec3 near_color : source_color = vec3(0.24, 0.31, 0.3);
uniform vec3 far_color : source_color = vec3(0.45, 0.52, 0.62);
uniform vec3 haze_color : source_color = vec3(0.72, 0.7, 0.72);
uniform vec3 sun_dir = vec3(0.42, 0.8, 0.45);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.66);

varying float v_layer;
varying float v_h;
varying float v_shade;

void vertex() {
	// UV.x: el ángulo de la silueta (rad); UV.y: 0 abajo, 1 en la cresta; UV2.x: la capa (0 cerca, 1 lejos); UV2.y: la
	// pendiente de ahí (para el lado al sol)
	float ang = UV.x - heading;
	float r = length(VERTEX.xz);
	VERTEX.x = cos(ang) * r;
	VERTEX.z = sin(ang) * r;
	v_layer = UV2.x;
	v_h = UV.y;
	vec2 out_dir = vec2(cos(ang), sin(ang));
	vec2 tang = vec2(-out_dir.y, out_dir.x);
	vec2 sd = normalize(sun_dir.xz + vec2(1e-4));
	v_shade = clamp(0.5 + 0.5 * UV2.y * dot(tang, sd) - 0.25 * dot(out_dir, sd), 0.0, 1.0);
}

void fragment() {
	vec3 col = mix(near_color, far_color, v_layer);
	col *= 0.9 + 0.2 * v_shade;
	col += sun_color * 0.05 * v_shade;
	// nieve en las cumbres de la capa lejana
	col = mix(col, mix(vec3(0.9, 0.91, 0.94), haze_color, 0.3), smoothstep(0.9, 0.97, v_h) * v_layer * 0.8);
	// la base se funde con la neblina del horizonte
	col = mix(haze_color, col, mix(0.55, 1.0, smoothstep(0.0, 0.4, v_h)) * (1.0 - 0.1 * v_layer));
	ALBEDO = col;
}
