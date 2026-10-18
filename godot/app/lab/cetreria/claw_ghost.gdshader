// Cetrería · la silueta fantasma de la forma natural sana de la garra (unidad 5h; dibujo): la de la ficha del animal, sin
// el crecimiento de más, para comparar con la de ahora. Una funda translúcida apenas más ancha que la garra, que solo se
// ve en el borde (de frente casi no tiñe) y a trazos a lo largo (para que no se confunda con algo de verdad); donde la
// garra se ha limado de más, se ve la punta que falta flotando en el aire. UV.x = s (mm desde la base).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled;

uniform vec3 color : source_color = vec3(0.6, 0.95, 0.85);
uniform float strength = 0.85;
uniform float grow_mm = 0.12;      // lo que sobresale de la garra (mm, a lo largo de la normal)
uniform float dash_mm = 1.6;       // largo de cada trazo
uniform float apex_mm = 30.0;      // dónde acaba la forma sana (la punta, más marcada)
uniform float from_mm = 0.0;       // desde dónde se dibuja (lo de antes queda dentro del dedo)

varying float v_s;

void vertex() {
	v_s = UV.x;
	VERTEX += NORMAL * grow_mm;
}

void fragment() {
	if (v_s < from_mm) {
		discard;
	}
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float dash = step(0.38, fract(v_s / dash_mm));
	float tip = smoothstep(apex_mm - 2.5, apex_mm, v_s);
	ALBEDO = color;
	ALPHA = clamp(rim * mix(0.35, 1.0, dash) * strength * (1.0 + tip * 0.4), 0.0, 1.0);
}
