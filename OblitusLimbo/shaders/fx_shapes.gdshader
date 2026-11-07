// Formas no chão e no ar: avisos (círculo/anel/cone/retângulo), ondas de choque, arcos de corte.
// mode: 0 aviso círculo, 1 aviso cone, 2 aviso retângulo, 3 onda (anel), 4 corte (arco), 5 disco de perigo
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform int mode = 0;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.15, 1.0);
uniform float fill = 0.0;
uniform float alpha = 1.0;
uniform float angle = 1.0;
uniform float inner = 0.0;
uniform float intensity = 1.6;
uniform float seed = 0.0;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float n1(float x) { float i = floor(x); float f = fract(x); return mix(hash(vec2(i, seed)), hash(vec2(i + 1.0, seed)), f * f * (3.0 - 2.0 * f)); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = 0.0;
	if (mode == 0 || mode == 1 || mode == 5) {
		if (r > 1.0 || r < inner) discard;
		if (mode == 1) {
			float ang = atan(p.x, -p.y);
			if (abs(ang) > angle * 0.5) discard;
		}
		float edge = smoothstep(0.86, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));
		float body = 0.16;
		float filled = step(r, fill) * 0.22;
		float pulse = 0.85 + 0.15 * sin(TIME * 22.0);
		a = (edge * 1.2 + body + filled) * pulse;
		if (mode == 5) a = (0.35 + 0.25 * n1(atan(p.y, p.x) * 6.0 + TIME * 2.0)) * (1.0 - smoothstep(0.6, 1.0, r));
	} else if (mode == 2) {
		// retângulo: UV.y = 0 na origem, 1 no fim
		float side = smoothstep(0.85, 0.97, abs(p.x));
		float body = 0.16;
		float filled = step(UV.y, fill) * 0.22;
		a = (side * 1.1 + body + filled) * (0.85 + 0.15 * sin(TIME * 22.0));
	} else if (mode == 3) {
		a = smoothstep(0.7, 0.93, r) * (1.0 - smoothstep(0.93, 1.0, r)) * 1.5 + smoothstep(0.3, 0.9, r) * 0.15 * step(r, 1.0);
	} else if (mode == 4) {
		// arco de corte: UV.x ao longo do arco, UV.y radial
		float along = pow(UV.x, 1.5) * (UV.x < 0.92 ? 1.0 : (1.0 - UV.x) / 0.08);
		float across = pow(sin(UV.y * 3.14159), 0.7) * (0.35 + 0.65 * UV.y);
		float n = 0.6 + 0.6 * n1(UV.x * 30.0 + UV.y * 5.0);
		a = along * across * n * 1.6;
	}
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
