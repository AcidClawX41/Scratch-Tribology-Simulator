// Cielo procedural de la carretera del coche en marcha (unidad 4h), como el de la nave del taller (lathe3d/workshop_sky):
// no se ve de fondo (el SubViewport es transparente y detrás está la tarjeta), pero es la luz ambiente y, sobre todo,
// lo que reflejan la pintura, las lunas, los cromados y los ojos. Atardecer a juego con la paleta: cenit añil, franja
// cálida en el horizonte, el halo del sol delante y arriba, nubes alargadas y el asfalto oscuro abajo, con el reflejo de
// «línea de horizonte» que se ve en la chapa de un coche de verdad. Nada descargado.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.15, 0.14, 0.24);
uniform vec3 mid_color : source_color = vec3(0.27, 0.26, 0.31);
uniform vec3 horizon_color : source_color = vec3(0.92, 0.80, 0.70);
uniform vec3 ground_near_color : source_color = vec3(0.19, 0.17, 0.19);
uniform vec3 ground_color : source_color = vec3(0.07, 0.06, 0.08);
uniform vec3 sun_dir = vec3(0.42, 0.8, 0.45);  // hacia el sol (el de la luz «Sol» de car_scene.gd)
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.66);
uniform float sun_energy = 5.0;
uniform float horizon_energy = 0.95;

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col;
	if (d.y >= 0.0) {
		float h = d.y;
		col = mix(mid_color, zenith_color, smoothstep(0.08, 0.85, h));
		col = mix(horizon_color * horizon_energy, col, smoothstep(0.0, 0.22, h));
		// nubes alargadas: bandas suaves en altura
		float band = sin(h * 38.0 + d.x * 2.3) * sin(h * 17.0 - d.z * 1.7);
		col *= 1.0 + 0.10 * smoothstep(0.4, 0.9, band) * smoothstep(0.05, 0.3, h) * (1.0 - smoothstep(0.5, 0.8, h));
		float s = max(dot(d, normalize(sun_dir)), 0.0);
		col += sun_color * (pow(s, 900.0) * sun_energy * 6.0 + pow(s, 12.0) * 0.55 + pow(s, 3.0) * 0.12);
	} else {
		float g = -d.y;
		col = mix(ground_near_color, ground_color, smoothstep(0.0, 0.35, g));
		col = mix(horizon_color * 0.35, col, smoothstep(0.0, 0.06, g));
	}
	COLOR = col;
}
