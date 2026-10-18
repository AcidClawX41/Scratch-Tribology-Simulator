// Cetrería · el cuero de la capucha de la rapaz (unidad 5i, petición 37; dibujo hecho en código): el grano del cuero (celdas
// pequeñas en relieve), el brillo apagado de la piel curtida, las costuras con sus puntadas a lo largo de UV.x (en mm,
// cada stitch_every mm alrededor) y el canto más oscuro donde acaba la pieza (cerca de UV.y = 0 o del largo total).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 leather_color : source_color = vec3(0.36, 0.22, 0.12);
uniform vec3 panel_color : source_color = vec3(0.16, 0.3, 0.2);
uniform vec3 thread_color : source_color = vec3(0.86, 0.8, 0.66);
uniform float grain_mm = 0.7;
uniform float stitch_every = 0.0;     // mm alrededor entre costuras (0: sin costuras)
uniform float stitch_mm = 2.2;        // largo de cada puntada
uniform float panel_from = -1.0;      // UV2.x desde el que va el color del panel (los ojos de la capucha); < 0, sin panel
uniform float panel_to = -1.0;

varying vec2 v_uv;
varying vec2 v_uv2;
varying vec4 v_col;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void vertex() {
	v_uv = UV;
	v_uv2 = UV2;
	v_col = COLOR;
}

void fragment() {
	vec2 p = v_uv / grain_mm;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + 0.15 + 0.7 * hash22(i + g) - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float px = max(length(fwidth(v_uv)), 1e-4);
	float kk = 1.0 - smoothstep(0.3, 0.8, px / grain_mm);
	float grain = smoothstep(0.0, 0.25, d2 - d1);
	vec3 col = leather_color;
	if (panel_from >= 0.0) {
		float pn = smoothstep(panel_from - 0.01, panel_from + 0.01, v_uv2.x) * (1.0 - smoothstep(panel_to - 0.01, panel_to + 0.01, v_uv2.x));
		pn *= 1.0 - smoothstep(0.32, 0.36, abs(v_uv2.y - 0.25) * 2.0);
		col = mix(col, panel_color, pn);
	}
	col *= mix(1.0, 0.86 + 0.14 * grain, kk);
	float h = mix(0.5, grain, kk);
	if (stitch_every > 0.0) {
		float seam = abs(fract(v_uv.y / stitch_every) - 0.5) * stitch_every;
		float st = (1.0 - smoothstep(0.25, 0.45, seam)) * step(0.45, fract(v_uv.x / stitch_mm));
		col = mix(col, col * 0.55, 1.0 - smoothstep(0.6, 1.1, seam));
		col = mix(col, thread_color, st * (1.0 - smoothstep(0.4, 1.0, px / stitch_mm)));
		h = mix(h, 0.2, 1.0 - smoothstep(0.5, 0.9, seam));
	}
	ALBEDO = col * (0.4 + 0.6 * v_col.r);
	ROUGHNESS = 0.62 - 0.12 * grain * kk;
	SPECULAR = 0.35;
	float hm = (h - 0.5) * 0.25 * 0.001;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(hm);
	float dhdy = dFdy(hm);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	vec3 nb = normalize(abs(det) * NORMAL - grad);
	NORMAL = mix(NORMAL, nb, step(1e-14, abs(det)));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		ALBEDO *= 0.5;
	}
}
