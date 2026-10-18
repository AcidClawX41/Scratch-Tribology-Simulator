// El paisaje del coche en marcha (unidad 4x): lo que comparten el campo y los árboles de scenery.gd con la carretera larga de
// la persecución (road_curve.gdshader): el eje de la carretera (path_p, BEND_N puntos en el plano xz desde x0 hasta x1 a lo
// largo, y su rumbo path_h) y lo recorrido (road_m). Un punto del paisaje se da en coordenadas de la carretera (a a lo largo,
// z de lado: + a la derecha) y se lleva a su sitio como el asfalto: p(a) + n(a)·z. Así sigue la recta, la curva y la S.
// Solo dibujo. Compatible con Forward+, Mobile y Compatibility.

const int BEND_N = 64;

uniform vec2 path_p[BEND_N];
uniform float path_h[BEND_N];
uniform float x0 = -40.0;
uniform float x1 = 260.0;
uniform float road_m = 0.0;

// El punto del eje y el rumbo en a (m a lo largo, de x0 a x1), y la curvatura de ahí (1/m, + a la izquierda).
void scenery_axis(float a, out vec2 p, out float h, out float k) {
	float u = clamp((a - x0) / (x1 - x0), 0.0, 1.0) * float(BEND_N - 1);
	int i = min(int(floor(u)), BEND_N - 2);
	float f = u - float(i);
	p = mix(path_p[i], path_p[i + 1], f);
	h = mix(path_h[i], path_h[i + 1], f);
	k = (path_h[i + 1] - path_h[i]) / ((x1 - x0) / float(BEND_N - 1));
}

// Lo de lado z del lado de dentro de una curva, sin pasar del centro (si no, el campo se doblaría sobre sí mismo y cruzaría la
// carretera): se comprime suavemente hasta el 85 % del radio. Devuelve el z que se usa; inner, cuánto del radio pedía (0-…).
float scenery_fold(float z, float k, out float inner) {
	inner = max(-k * z, 0.0);
	if (inner <= 0.0) {
		return z;
	}
	float s = 0.85 * (1.0 - exp(-inner / 0.85));
	return -s / k;
}

// La posición en el mundo (y = 0) de un punto (a, z) de la carretera, con el pliegue del lado de dentro.
vec3 scenery_place(float a, float z, out float inner, out float head) {
	vec2 p;
	float h;
	float k;
	scenery_axis(a, p, h, k);
	float zz = scenery_fold(z, k, inner);
	head = h;
	vec2 n = vec2(sin(h), cos(h));
	return vec3(p.x + n.x * zz, 0.0, p.y + n.y * zz);
}

// Ruido de valor (dibujo).
float sc_h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sc_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(sc_h21(i), sc_h21(i + vec2(1.0, 0.0)), u.x), mix(sc_h21(i + vec2(0.0, 1.0)), sc_h21(i + vec2(1.0, 1.0)), u.x), u.y);
}
