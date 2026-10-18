// Perfil del bisel de una hoja (cuchillo, hacha o cuchilla de cortacésped): espesor a la distancia d (m) del filo.
// Lo comparten la hoja 3D (blade.gdshader) y su sección (section.gdshader), para que el corte enseñe exactamente el
// mismo bisel. Es geometría de dibujo: el ángulo es el que pide set_state y el radio, el de la muela.
// - Contra la periferia de una muela el bisel sale cóncavo («vaciado»), con el radio de la muela: la cara es un arco
//   de la circunferencia de la muela, tangente al ángulo pedido en el vértice.
// - Contra la cara de un disco o con hollow_r = 0, plano.
// - Bisel de un solo lado (cuchilla de cortacésped): la cara B queda plana y el ángulo es el total, en la cara A.
// El ángulo cambia solo con un uniforme: no hay que rehacer la malla si la mano lo mueve de un fotograma a otro.

uniform float bevel_tan = 0.268;   // tan(ángulo por lado) · en un solo bisel, tan(ángulo total)
uniform float hollow_r = 0.0;      // m: radio de la muela para el vaciado; 0 = bisel plano
uniform float edge_half = 2e-6;    // m: semiespesor mínimo del vértice (de dibujo, no un radio medido)
uniform float two_sided = 1.0;     // 1: bisel a los dos lados · 0: un solo bisel, en la cara A (side > 0)

// Distancia de la cara del bisel a la línea media (dos lados) o a la cara plana (un lado), a d del vértice.
float bevel_half(float d) {
	if (hollow_r <= 0.0) {
		return d * bevel_tan;
	}
	float c = inversesqrt(1.0 + bevel_tan * bevel_tan);
	float s = bevel_tan * c;
	float xx = d + hollow_r * s;
	if (xx >= hollow_r) {
		return 1e3;
	}
	return hollow_r * c - sqrt(hollow_r * hollow_r - xx * xx);
}

float bevel_slope(float d) {
	if (hollow_r <= 0.0) {
		return bevel_tan;
	}
	float c = inversesqrt(1.0 + bevel_tan * bevel_tan);
	float s = bevel_tan * c;
	float xx = d + hollow_r * s;
	float q = hollow_r * hollow_r - xx * xx;
	return q > 1e-14 ? xx * inversesqrt(q) : 1e3;
}

// Coordenada z de la cara `side` (+1 cara A, −1 cara B) a la distancia d, con el semiespesor del cuerpo hb y su
// pendiente hbs. Devuelve (z, pendiente dz/dd, 1 si está en el bisel).
vec3 blade_face(float d, float side, float hb, float hbs) {
	float hv = bevel_half(d);
	if (two_sided > 0.5) {
		bool ground = hv < hb;
		float h = ground ? max(hv, edge_half) : hb;
		float sl = ground ? bevel_slope(d) : hbs;
		return vec3(side * h, side * sl, ground ? 1.0 : 0.0);
	}
	// Un solo bisel: la cara B es plana (z = −hb); la A baja hasta ella con el ángulo total
	if (side < 0.0) {
		return vec3(-hb, -hbs, 0.0);
	}
	bool ground = hv < 2.0 * hb;
	float t = ground ? max(hv, 2.0 * edge_half) : 2.0 * hb;
	float sl = ground ? bevel_slope(d) - hbs : hbs;
	return vec3(t - hb, sl, ground ? 1.0 : 0.0);
}
