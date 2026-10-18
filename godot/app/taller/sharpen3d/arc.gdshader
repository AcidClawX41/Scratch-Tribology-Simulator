// Arco del ángulo en la vista de sección: una tira de t ∈ [0, 1] (UV.x) y de anchura (UV.y ∈ [0, 1]) que el vértice
// abre hasta `angle` rad en el plano yz local, desde +y hacia +z. Así el arco sigue al ángulo de cada fotograma sin
// rehacer la malla. Sin luz y por encima del dibujo de la sección.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform float angle = 0.26;
uniform float radius = 0.004;
uniform float width = 0.00012;
uniform vec3 color : source_color = vec3(0.9, 0.71, 0.31);

void vertex() {
	float a = UV.x * angle;
	float rr = radius + (UV.y - 0.5) * width;
	VERTEX = vec3(0.0, cos(a) * rr, sin(a) * rr);
}

void fragment() {
	ALBEDO = color;
}
