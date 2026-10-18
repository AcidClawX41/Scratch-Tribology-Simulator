// Rebaba: una línea fina y brillante a lo largo del filo (o de los labios de la broca y la fresa). Su brillo es el
// `burr` de set_state (0-1): la rebaba es el hilo de metal que se dobla al otro lado cuando el bisel llega al vértice,
// y se ve como un destello continuo al girar la hoja bajo la luz. `phase` (s, reloj de la escena) mueve ese destello
// a lo largo del filo. UV.x: posición a lo largo del filo. Aditivo y sin luz.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 glint_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float burr = 0.0;
uniform float phase = 0.0;

void fragment() {
	float wave = 0.55 + 0.45 * sin(UV.x * 38.0 - phase * 4.0);
	float k = clamp(burr, 0.0, 1.0);
	ALBEDO = glint_color * k * wave * 1.6;
	ALPHA = k;
}
