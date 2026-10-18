// Estelas de las chispas: un quad por chispa en un MultiMesh que llena core/taller/sparks.gd.
// La transformación de cada instancia no es una transformación normal, son datos: origen = cabeza de la estela,
// base X = de la cabeza a la cola (lo recorrido durante la exposición de la cámara), |base Y| = anchura.
// El quad (x ∈ [0, 1], y ∈ [−0,5, 0,5]) se orienta de cara a la cámara alrededor de la estela.
// Aditivo: donde se cruzan muchas chispas se satura a blanco, como en una foto. Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float intensity = 1.35;

varying vec4 v_col;
varying vec2 v_q;

void vertex() {
	vec2 q = VERTEX.xy;
	vec3 head = MODEL_MATRIX[3].xyz;
	vec3 streak = MODEL_MATRIX[0].xyz;
	float width = length(MODEL_MATRIX[1].xyz);
	vec3 p = head + streak * q.x;
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 to_cam = ortho ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz - p);
	vec3 side = cross(streak, to_cam);
	float sl = length(side);
	side = sl > 1e-12 ? side / sl : INV_VIEW_MATRIX[1].xyz;
	p += side * width * q.y * mix(1.0, 0.45, q.x);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	v_col = COLOR;
	v_q = q;
}

void fragment() {
	// La partícula está incandescente todo el recorrido: la estela brilla casi igual de punta a punta y solo se
	// apaga en el último tramo de la cola.
	float across = clamp(1.0 - abs(v_q.y) * 2.0, 0.0, 1.0);
	float tail = smoothstep(1.0, 0.8, v_q.x);
	float a = v_col.a * sqrt(across) * mix(0.35, 1.0, tail);
	ALBEDO = v_col.rgb * intensity;
	ALPHA = clamp(a, 0.0, 1.0);
}
