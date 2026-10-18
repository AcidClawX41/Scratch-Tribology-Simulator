// Cetrería · el paño de microfibra que limpia la lente (unidad 5t-B, dibujo), para lens.gdshader y lens_simple.gdshader.
// Está pegado a la lente, así que se ve desenfocado: una almohadilla gris azulada de bordes blandos que entra por la
// izquierda y cruza en arco, con los pliegues suaves de la tela, la trama fina de la microfibra (de poco contraste, por el
// desenfoque) y más oscura hacia el borde (la sombra de la mano detrás). Su borde de ataque pasa por x = wipe.
// cloth() → rgb y alfa (0 fuera del paño).

float cloth_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// El borde de ataque del paño (x normalizada) cuando el barrido va por w (0 a 1,15): lo que ya ha limpiado queda a su
// izquierda (lens_layer.gd usa la misma cuenta para quitar las manchas).
float cloth_edge(float w) {
	return w * 1.6 - 0.08;
}

vec4 cloth(vec2 uv, float w, vec2 vpx) {
	if (w < 0.0) {
		return vec4(0.0);
	}
	// la almohadilla: elipse (en la pantalla normalizada), algo girada, que sube y baja en arco al cruzar
	float rx = 0.22;
	float ry = 0.55;
	vec2 c = vec2(cloth_edge(w) - rx, 0.58 - 0.16 * sin(3.14159 * clamp(w, 0.0, 1.0)));
	float ang = -0.35 + 0.3 * w;
	vec2 p = uv - c;
	p = vec2(cos(ang) * p.x - sin(ang) * p.y, sin(ang) * p.x + cos(ang) * p.y);
	float r = length(p / vec2(rx, ry));
	float a = 1.0 - smoothstep(0.78, 1.0, r);
	if (a <= 0.0) {
		return vec4(0.0);
	}
	// los pliegues (ondas suaves a lo largo de la tela), la trama de la microfibra y la sombra del borde
	float fold = 0.88 + 0.12 * sin(p.x * 26.0 + 4.0 * sin(p.y * 6.0));
	float fib = cloth_hash(floor(uv * vpx / 1.5)) * 0.05 + cloth_hash(floor(uv * vpx / 5.0)) * 0.04;
	float shade = mix(0.62, 1.0, 1.0 - r * r);
	vec3 col = vec3(0.56, 0.6, 0.66) * fold * shade + vec3(fib);
	return vec4(col, a * 0.97);
}
