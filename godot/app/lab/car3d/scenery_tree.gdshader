// Los árboles del paisaje del coche en marcha (unidad 4x, scenery.gd): un MultiMesh por especie, con el tronco y la copa de
// su malla (colores de vértice) y, por árbol, en INSTANCE_CUSTOM su sitio en la carretera (a0 a lo largo, z de lado), su
// tamaño y su giro, y en el color de la instancia su tono (Godot lo multiplica por el de los vértices). Cada árbol corre con lo recorrido y vuelve a entrar por
// delante cuando sale por detrás (a = x0 + (a0 − road_m) mód. largo): una carretera sin fin con los mismos nodos. Siguen
// el trazado (scenery_path.gdshaderinc); los del lado de dentro de una curva demasiado cerrada se esconden (se doblarían
// sobre la carretera). Un vaivén suave con el viento, más en lo alto. Solo dibujo.
// Compatible con Forward+, Mobile y Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://app/lab/car3d/scenery_path.gdshaderinc"

uniform float sway = 1.0;

varying vec3 v_tint;
varying float v_crown;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float len = x1 - x0;
	float a = x0 + mod(c.x - road_m - x0, len);
	float inner;
	float head;
	vec3 w = scenery_place(a, c.y, inner, head);
	float hide = step(0.7, inner);
	float s = c.z * (1.0 - hide);
	float ca = cos(c.w);
	float sa = sin(c.w);
	vec3 v = VERTEX * s;
	// el vaivén: lo alto de la copa se mece unos centímetros (por árbol, con su fase)
	float top = clamp(VERTEX.y, 0.0, 1.0);
	float ph = c.x * 0.37 + c.y * 0.21;
	v.x += sin(TIME * 1.3 + ph) * 0.05 * s * top * top * sway;
	v = vec3(ca * v.x + sa * v.z, v.y, -sa * v.x + ca * v.z);
	NORMAL = vec3(ca * NORMAL.x + sa * NORMAL.z, NORMAL.y, -sa * NORMAL.x + ca * NORMAL.z);
	VERTEX = w + v;
	v_crown = COLOR.a;
	// COLOR ya trae el tono de la instancia multiplicado (MultiMesh.use_colors)
	v_tint = vec3(1.0);
}

void fragment() {
	vec3 col = COLOR.rgb * v_tint;
	// la copa, algo más oscura por dentro (las hojas se tapan): con la normal, lo que mira al suelo
	col *= mix(1.0, 0.7 + 0.3 * smoothstep(-0.6, 0.6, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y), v_crown);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, v_crown);
	METALLIC = 0.0;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.12, 0.16, 0.05) * v_crown;
}
