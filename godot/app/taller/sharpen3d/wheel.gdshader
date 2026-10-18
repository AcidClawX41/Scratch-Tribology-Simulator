// Muela, piedra, rueda de cuero o muela de copa de la afiladora 3D (sólido de revolución alrededor del eje X local).
// El giro no mueve la malla: el dibujo se gira aquí con el ángulo que enseña la escena (`spin`) y se emborrona con el
// arco que barre la muela durante la exposición de la cámara (`blur`, rad). Con 1/60 s de exposición, una muela a
// 2950 rpm barre 295°: el grano se funde en anillos, como lo ve el ojo, en vez de pintar un giro que a 30–60
// fotogramas por segundo daría el efecto estroboscópico (parecería quieta o marcha atrás). La piedra lenta a 100 rpm
// barre 10°: se ve girar de verdad, con el grano apenas corrido. Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int kind = 0;               // 0 muela vitrificada · 1 piedra húmeda · 2 cuero · 3 muela de copa (capa de CBN o diamante)
uniform vec3 grain_color : source_color = vec3(0.56, 0.52, 0.49);
uniform vec3 grain_dark : source_color = vec3(0.37, 0.34, 0.32);
uniform float grit_mm = 0.4;        // tamaño aparente del grano (mm)
uniform float radius_mm = 75.0;
uniform float half_width_mm = 8.0;
uniform float bore_mm = 16.0;
uniform float label_mm = 0.0;       // radio de la etiqueta de papel de las muelas vitrificadas (0: sin etiqueta)
uniform vec3 label_color : source_color = vec3(0.86, 0.83, 0.76);
uniform vec3 body_color : source_color = vec3(0.62, 0.64, 0.67);
uniform float layer_mm = 3.0;       // espesor de la capa abrasiva de la muela de copa
uniform float rim_in_mm = 28.0;     // radio interior del anillo abrasivo de la muela de copa
uniform float spin = 0.0;           // ángulo que se enseña (rad)
uniform float blur = 0.0;           // arco barrido durante la exposición (rad)
uniform float wet = 0.0;            // 0 seca · 1 empapada

varying vec3 v_mm;
varying vec3 v_n;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_mm = VERTEX * 1000.0;
	v_n = NORMAL;
}

vec3 grit_at(vec2 q, float g) {
	float h = hash21(floor(q / g));
	float h2 = hash21(floor(q / (g * 2.7)) + vec2(17.0, 3.0));
	return mix(grain_dark, grain_color, 0.25 + 0.75 * h) * (0.86 + 0.28 * h2);
}

// Dibujo en el ángulo th (rad, ya en el marco de la muela): periferia (arco × ancho) o cara (radio × arco).
vec3 pattern(float r, float th, float x, bool face) {
	float g = max(grit_mm, 0.05);
	if (face) {
		return grit_at(vec2(r, th * max(r, 1.0)), g * 1.4);
	}
	return grit_at(vec2(th * radius_mm, x), g);
}

// Lo que queda del dibujo cuando la muela barre más de una vuelta en la exposición: anillos (caras) o rayas a lo
// largo de la vuelta (periferia).
vec3 streaks(float r, float x, bool face) {
	float g = max(grit_mm, 0.05);
	vec3 mean_c = mix(grain_dark, grain_color, 0.62);
	vec3 row = face ? grit_at(vec2(r, 0.37), g * 1.4) : grit_at(vec2(0.37, x), g);
	return mix(mean_c, row, 0.45);
}

void fragment() {
	float r = length(v_mm.yz);
	float th0 = atan(v_mm.z, v_mm.y) - spin;
	bool face = abs(v_n.x) > 0.7;
	vec3 col;
	float metal = 0.0;
	float rough = 0.82;
	if (kind == 3 && !(face && v_n.x > 0.0 && r > rim_in_mm)) {
		// Muela de copa: cuerpo de metal; solo el anillo de la cara que trabaja lleva la capa abrasiva
		col = body_color;
		metal = 0.8;
		rough = 0.35;
	} else if (r < bore_mm + 0.8 && !face) {
		col = vec3(0.12);
	} else {
		col = vec3(0.0);
		int taps = blur > 0.02 ? 7 : 1;
		for (int i = 0; i < 7; i++) {
			if (i >= taps) {
				break;
			}
			float off = taps > 1 ? float(i) / 6.0 * min(blur, 1.2) : 0.0;
			col += pattern(r, th0 + off, v_mm.x, face);
		}
		col /= float(taps);
		col = mix(col, streaks(r, v_mm.x, face), smoothstep(0.6, 3.0, blur));
		if (kind == 0 && face && label_mm > 0.0 && r < label_mm && r > bore_mm + 1.5) {
			// Etiqueta de papel (secante) de las muelas vitrificadas, con su filete impreso
			col = label_color;
			float ring = step(abs(r - (label_mm - 2.0)), 0.5) + step(abs(r - (bore_mm + 4.0)), 0.4);
			col = mix(col, vec3(0.2, 0.22, 0.26), clamp(ring, 0.0, 1.0));
			rough = 0.9;
		}
		if (kind == 2) {
			// Cuero: pasta de asentar (óxido de cromo) en la periferia
			col = mix(col, vec3(0.34, 0.42, 0.3), face ? 0.0 : 0.35);
			rough = 0.62;
		}
	}
	float w = clamp(wet, 0.0, 1.0);
	col *= 1.0 - 0.4 * w;
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = mix(rough, 0.22, w);
	SPECULAR = mix(0.4, 0.7, w);
}
