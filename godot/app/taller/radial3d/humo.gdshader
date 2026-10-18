// Humo de la pintura y del plástico que se queman: bocanadas redondas y blandas mirando a la cámara, en un
// MultiMesh que llena radial3d/smoke.gd (origen = centro, |base X| = tamaño, color con alfa, custom.x = semilla).
// Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

varying vec4 v_col;
varying vec2 v_q;
varying float v_seed;

void vertex() {
	vec2 q = VERTEX.xy;
	vec3 center = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 p = center + (right * q.x + up * q.y) * size;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	v_col = COLOR;
	v_q = q;
	v_seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	float r = length(v_q) * 2.0;
	float wisp = sin(v_q.x * 9.0 + v_seed * 20.0) * sin(v_q.y * 7.0 - v_seed * 13.0) * 0.18;
	float a = smoothstep(1.0, 0.15, r + wisp) * v_col.a;
	ALBEDO = v_col.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
