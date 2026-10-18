// Cetrería · la lente de la cámara (unidad 5t-B, dibujo): un efecto de pantalla sobre la vista 3D, no objetos en la escena.
// Lee lo que hay detrás (la imagen de la cámara) y el mapa de daños de la lente (lens_shapes.gd, tres partes del ancho de
// la vista: A = surco, borde y grietas; B = grasa, lechoso y veladura; C = el color de lo que se queda pegado):
//   - el surco de cada rayón desvía un poco la luz (refracción: unos píxeles hacia donde baja la pared del surco) y brilla
//     donde su pared mira a la luz (el reflejo se mueve un poco con la cámara: light_dir);
//   - el borde levantado blanquecino (plástico) o las esquirlas (vidrio), la grieta con sus líneas brillantes y su zona
//     lechosa, la grasa con su irisación y el metal que se queda pegado;
//   - donde hay rayones, grasa o zona lechosa la imagen pierde contraste y nitidez (se lee más arriba en sus mipmaps), tanto
//     más cuanto más rayada está la lente (obscuration, el índice de juego del motor);
//   - la calidad de la lente: la de plástico, algo menos nítida y con un poco de viñeta (soft_lod, vignette, tint);
//   - el destello del impacto y el paño de microfibra que pasa limpiando (wipe: por dónde va; lens_cloth.gdshaderinc).
// Coste: 7 lecturas del mapa y 2 de la imagen por píxel. Sin daños ni calidad que enseñar, la capa ni se dibuja.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D damage_map : filter_linear, repeat_disable;
// tamaño de una parte del mapa (px) y de la vista (px)
uniform vec2 map_px = vec2(1280.0, 560.0);
uniform vec2 view_px = vec2(1280.0, 560.0);
uniform bool has_damage = false;
uniform float refract_px = 3.5;
uniform vec2 light_dir = vec2(-0.55, -0.83);
uniform float obscuration = 0.0;
uniform float soft_lod = 0.0;
uniform float vignette = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform vec2 flash_at = vec2(0.5);
uniform float wipe = -1.0;
uniform float time = 0.0;

#include "res://app/lab/cetreria/reaction/lens_cloth.gdshaderinc"

vec4 part(vec2 uv, float k) {
	vec2 h = 0.5 / map_px;
	vec2 q = clamp(uv, h, vec2(1.0) - h);
	return texture(damage_map, vec2((k + q.x) / 3.0, q.y));
}

// lo que hunde la lente en uv: el surco y, algo menos, las líneas de grieta
float relief(vec2 uv) {
	vec4 a = part(uv, 0.0);
	return a.r + 0.6 * a.b;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec2 suv = SCREEN_UV;
	vec3 col;
	if (!has_damage) {
		col = textureLod(screen_tex, suv, soft_lod).rgb;
	} else {
		vec4 a = part(uv, 0.0);
		vec4 b = part(uv, 1.0);
		vec4 c = part(uv, 2.0);
		// el paño ya ha pasado por aquí: sin la grasa ni el polvo
		float wiped = wipe >= 0.0 ? 1.0 - smoothstep(cloth_edge(wipe) - 0.12, cloth_edge(wipe) - 0.06, uv.x) : 0.0;
		b.r *= 1.0 - wiped;
		// la pendiente del relieve (para la refracción y el brillo)
		vec2 tx = 1.0 / map_px;
		vec2 grad = vec2(relief(uv + vec2(tx.x, 0.0)) - relief(uv - vec2(tx.x, 0.0)), relief(uv + vec2(0.0, tx.y)) - relief(uv - vec2(0.0, tx.y)));
		vec2 off = grad * refract_px / view_px;
		float haze = clamp(b.b, 0.0, 1.0);
		float milky = clamp(b.g, 0.0, 1.0);
		float grease = clamp(b.r, 0.0, 1.0);
		float ob = clamp(obscuration, 0.0, 1.0);
		// menos nítida donde hay daños (más cuanto más rayada está la lente)
		float lod = soft_lod + haze * (0.4 + 2.6 * ob) + grease * 2.2 + milky * 2.0;
		col = textureLod(screen_tex, suv + off, lod).rgb;
		// menos contraste: la imagen se aplana hacia su media de alrededor, algo aclarada (la luz que esparce el rayón)
		vec3 mean = textureLod(screen_tex, suv, 5.0).rgb;
		float lum = dot(mean, vec3(0.299, 0.587, 0.114));
		float veil = clamp(haze * (0.08 + 0.62 * ob) + milky * 0.5 + grease * 0.38, 0.0, 0.9);
		col = mix(col, mix(mean, vec3(lum), 0.4) + vec3(0.07), veil);
		// el surco: algo más oscuro en el fondo (la luz que se va de lado) y brillante en la pared que mira a la luz
		float g2 = length(grad);
		vec2 gn = g2 > 1e-5 ? grad / g2 : vec2(0.0);
		float glint = pow(clamp(dot(gn, normalize(light_dir)), 0.0, 1.0), 5.0) * clamp(g2 * 2.5, 0.0, 1.0);
		col = mix(col, col * 0.78 + vec3(0.05), clamp(a.r * 0.4, 0.0, 0.45));
		col += vec3(1.0, 0.97, 0.92) * glint * 0.85;
		// el borde levantado (blanquecino) o las esquirlas (vidrio), y el polvo
		col = mix(col, vec3(0.9, 0.91, 0.93), clamp(a.g * 0.6, 0.0, 0.8));
		// las líneas de la grieta: brillantes, con su lado oscuro
		col = mix(col, vec3(0.94, 0.96, 1.0), clamp(a.b * 0.75, 0.0, 0.85));
		// la zona lechosa
		col = mix(col, vec3(0.84, 0.86, 0.88), milky * 0.32);
		// la grasa: algo amarillenta, con irisación de película fina donde la luz roza (solo un poco); el polvo, motas claras
		col = mix(col, vec3(0.66, 0.62, 0.52), clamp(grease * 0.32, 0.0, 0.32));
		float film = grease * (0.5 + 0.5 * sin(uv.x * 37.0 + uv.y * 23.0 + grease * 19.0));
		col += film * 0.05 * vec3(0.6 + 0.4 * sin(grease * 17.0), 0.6 + 0.4 * sin(grease * 17.0 + 2.1), 0.6 + 0.4 * sin(grease * 17.0 + 4.2));
		col = mix(col, vec3(0.86, 0.84, 0.8), smoothstep(0.8, 0.98, grease) * 0.7);
		// lo que se queda pegado (metal, grasa, polvo): su color
		float dep = max(max(c.r, c.g), c.b);
		col = mix(col, c.rgb / max(dep, 1e-4), clamp(dep * 1.6, 0.0, 0.7));
	}
	// el paño de microfibra que pasa (lens_cloth.gdshaderinc)
	vec4 cl = cloth(uv, wipe, view_px);
	col = mix(col, cl.rgb, cl.a);
	// la calidad de la lente: el color y la viñeta
	col *= tint;
	vec2 d = (uv - 0.5) * vec2(view_px.x / max(view_px.y, 1.0), 1.0);
	col *= 1.0 - vignette * smoothstep(0.2, 1.1, dot(d, d));
	// el destello del impacto
	vec2 fd = (uv - flash_at) * vec2(view_px.x / max(view_px.y, 1.0), 1.0);
	col += vec3(flash) * (0.3 + 0.7 * exp(-dot(fd, fd) * 9.0));
	COLOR = vec4(col, 1.0);
}
