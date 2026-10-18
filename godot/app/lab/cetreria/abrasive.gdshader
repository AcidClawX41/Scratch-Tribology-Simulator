// Cetrería · la cara que corta de cada herramienta (dibujo): el picado de una lima de acero (dientes por mm de DIN 8349,
// picado sencillo o doble), el grano de una lima de diamante, de una lima de cartón de corindón o de la banda de lija
// del tambor del torno. UV en mm sobre la cara (UV.x a lo largo de la herramienta o de la vuelta del tambor, UV.y a
// lo ancho). En el tambor, `spin` gira el dibujo y `blur` lo emborrona con el arco que barre en la exposición, como
// la muela de la afiladora del taller (a 6500 rpm, 1/60 s son 650°: se ven anillos).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;                 // 0 lima de dientes · 1 grano
uniform float teeth_per_mm = 1.3;     // dientes por mm (13 por cm la bastarda)
uniform float double_cut = 1.0;       // picado doble
uniform vec3 steel : source_color = vec3(0.56, 0.58, 0.6);
uniform float grain_mm = 0.05;        // tamaño del grano (mm)
uniform vec3 grain_color : source_color = vec3(0.45, 0.33, 0.22);
uniform vec3 bond_color : source_color = vec3(0.3, 0.22, 0.15);
uniform float metal_grain = 0.0;      // grano de diamante sobre acero (brilla)
uniform float spin = 0.0;             // desplazamiento del dibujo a lo largo de UV.x (mm)
uniform float blur = 0.0;             // arco barrido (mm) durante la exposición
uniform float circumference = 40.0;   // vuelta del tambor (mm) para que el dibujo cierre
uniform float wear = 0.0;             // polvo de queratina encima (0-1)
uniform vec2 uv_mm = vec2(1.0, 1.0);  // tamaño de la cara (mm): pasa las UV 0-1 de la malla a mm
uniform float v_scale = 1.0;          // el lado de un CylinderMesh solo usa V de 0 a 0,5 (las tapas, el resto): 2 en el tambor
// Unidad 5l: lo gastada que está la herramienta (ClawCareKit): en la banda que ha trabajado (glaze_width mm, centrada a lo
// ancho de la cara o del tambor), la lima embotada (las crestas de los dientes romas y pulidas) o el grano vidriado (las
// puntas planas que brillan). glaze 0-1: el ancho de la plataforma de los filos frente a su tamaño.
uniform float glaze = 0.0;
uniform float glaze_width = 2.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float teeth(vec2 uv) {
	// una fila de dientes cada 1/teeth_per_mm mm, inclinada ~25° (picado superior) y, en el doble, otra a ~45°
	float a = fract((uv.x + uv.y * 0.47) * teeth_per_mm);
	float t1 = smoothstep(0.0, 0.18, a) * (1.0 - smoothstep(0.55, 1.0, a));
	float b = fract((uv.x - uv.y * 1.0) * teeth_per_mm * 0.8);
	float t2 = smoothstep(0.0, 0.25, b) * (1.0 - smoothstep(0.6, 1.0, b));
	return mix(t1, t1 * 0.6 + t2 * 0.6, double_cut);
}

void fragment() {
	vec3 col;
	float rough;
	float metal;
	vec2 uvmm = vec2(UV.x, UV.y * v_scale) * uv_mm;
	if (mode == 0) {
		float t = teeth(uvmm);
		col = steel * (0.55 + 0.6 * t);
		rough = mix(0.62, 0.28, t);
		metal = 0.85;
	} else {
		vec2 uv = uvmm;
		uv.x = mod(uv.x + spin, circumference);
		float g = 0.0;
		if (blur > grain_mm * 2.0) {
			// emborronado: el grano se funde en anillos a lo largo de la vuelta
			g = hash21(vec2(0.0, floor(uv.y / grain_mm))) * 0.6 + 0.2;
		} else {
			vec2 cell = floor(uv / grain_mm);
			vec2 f = fract(uv / grain_mm) - 0.5;
			float h = hash21(cell);
			float r = 0.25 + 0.2 * hash21(cell + 7.0);
			g = step(0.35, h) * (1.0 - smoothstep(r * 0.7, r, length(f)));
		}
		col = mix(bond_color, grain_color, g);
		rough = mix(0.85, mix(0.55, 0.2, metal_grain), g);
		metal = metal_grain * g;
	}
	col = mix(col, vec3(0.78, 0.72, 0.62), wear * 0.6);
	if (glaze > 0.0) {
		// la banda que ha trabajado: con los bordes suaves, a lo ancho de la cara (o del tambor) y a todo lo largo
		float d = abs(uvmm.y - uv_mm.y * 0.5);
		float band = (1.0 - smoothstep(glaze_width * 0.5, glaze_width * 0.5 + 0.8, d)) * glaze;
		if (mode == 0) {
			// dientes romos: las crestas se aplanan y se pulen (planas, claras y lisas: brillan con la luz) y, cuanto más
			// gastada, más ancha la plataforma de cada diente; los valles siguen oscuros
			float crest = smoothstep(0.45 - 0.3 * glaze, 0.75 - 0.3 * glaze, teeth(uvmm));
			col = mix(col, steel * 1.6, band * crest);
			rough = mix(rough, 0.15, band * (0.3 + 0.7 * crest));
		} else {
			// grano vidriado: las puntas, planas y brillantes; el conjunto, más uniforme
			col = mix(col, mix(col, vec3(0.86), 0.35), band);
			rough = mix(rough, 0.12, band);
			metal = mix(metal, 0.25, band * 0.6);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
