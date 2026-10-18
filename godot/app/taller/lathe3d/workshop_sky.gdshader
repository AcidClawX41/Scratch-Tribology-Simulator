// Cielo procedural de una nave de taller (unidad 9): techo oscuro con filas de luminarias lineales, paredes claras
// con ventanal alto y suelo de hormigón. Es el fondo y, sobre todo, el entorno de los reflejos: las luminarias
// alargadas dejan en las piezas torneadas las líneas de brillo que se ven en un taller de verdad. Nada descargado.
shader_type sky;

uniform vec3 ceiling_color : source_color = vec3(0.13, 0.135, 0.14);
uniform vec3 wall_color : source_color = vec3(0.58, 0.60, 0.58);
uniform vec3 wall_low_color : source_color = vec3(0.40, 0.42, 0.41);
uniform vec3 floor_color : source_color = vec3(0.36, 0.36, 0.35);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.97, 0.92);
uniform float lamp_energy = 7.0;
uniform vec3 window_color : source_color = vec3(0.78, 0.86, 0.96);
uniform float window_energy = 1.4;
uniform float hall_height = 5.5;  // altura de las luminarias sobre el punto de vista (m)
uniform float hall_half_width = 12.0;  // distancia a las paredes (m)
uniform float eye_height = 1.6;  // altura del punto de vista sobre el suelo (m)
uniform float window_bottom = 2.9;  // la ventana, del alféizar al dintel, en altura sobre el suelo (m): en la nave, alta;
uniform float window_top = 4.7;  // en una sala baja (la cetrería, 1,6 m de techo) hay que bajarla o queda por encima del techo

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col;
	if (d.y > 0.0) {
		float t_ceil = hall_height / max(d.y, 1e-4);
		float t_wall = hall_half_width / max(max(abs(d.x), abs(d.z)), 1e-4);
		if (t_ceil < t_wall) {
			vec2 p = d.xz * t_ceil;
			// Luminarias lineales de 1,5 × 0,22 m, en filas cada 3 m y a 4 m unas de otras dentro de la fila
			vec2 cell = vec2(mod(p.x + 2.0, 4.0) - 2.0, mod(p.y + 1.5, 3.0) - 1.5);
			float lx = 1.0 - smoothstep(0.70, 0.80, abs(cell.x));
			float lz = 1.0 - smoothstep(0.09, 0.13, abs(cell.y));
			float fade = exp(-length(p) * 0.035);
			// Cerchas del techo: bandas más oscuras cada 6 m
			float truss = 1.0 - 0.35 * (1.0 - smoothstep(0.05, 0.15, abs(mod(p.x, 6.0) - 3.0)));
			col = ceiling_color * truss * (0.75 + 0.25 * fade) + lamp_color * lamp_energy * lx * lz * fade;
		} else {
			vec3 hit = d * t_wall;
			float h = hit.y + eye_height;  // altura sobre el suelo
			float win = smoothstep(window_bottom, window_bottom + 0.2, h) * (1.0 - smoothstep(window_top - 0.1, window_top + 0.1, h));
			float u = abs(d.x) > abs(d.z) ? hit.z : hit.x;
			float mullion = 1.0 - smoothstep(0.90, 0.95, abs(mod(u, 2.0) - 1.0));  // montantes cada 2 m
			// Estanterías y máquinas lejanas: bloques oscuros a media altura
			float blocks = step(h, 1.9) * step(0.45, hash21(floor(vec2(u * 0.5, 0.0))));
			vec3 wall = mix(wall_low_color, wall_color, smoothstep(0.0, 2.5, h));
			wall = mix(wall, wall_low_color * 0.45, blocks * 0.8);
			col = wall + window_color * window_energy * win * mullion;
		}
	} else {
		float t_floor = eye_height / max(-d.y, 1e-4);
		vec2 p = d.xz * t_floor;
		float joint = smoothstep(1.45, 1.49, max(abs(mod(p.x, 3.0) - 1.5), abs(mod(p.y, 3.0) - 1.5)));  // juntas cada 3 m
		float slabs = 1.0 - 0.12 * joint;
		col = floor_color * slabs * (0.9 + 0.1 * hash21(floor(p * 0.5)));
	}
	COLOR = col;
}
