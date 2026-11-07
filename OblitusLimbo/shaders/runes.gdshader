// Runas emissivas procedurais (faixas em árvores, anéis, pilares). UV.x ao redor, UV.y altura.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 color : source_color = vec4(0.25, 0.6, 1.0, 1.0);
uniform float reveal = 1.0;
uniform float intensity = 2.5;
uniform vec2 cells = vec2(24.0, 3.0);
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void fragment() {
	vec2 g = UV * cells;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float glyph = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = hash(id + float(k) * 7.1) * 6.2831;
		vec2 d = vec2(cos(a), sin(a));
		float off = (hash(id + float(k) * 3.3) - 0.5) * 0.5;
		float line = abs(dot(f, vec2(-d.y, d.x)) - off);
		float len = abs(dot(f, d));
		glyph += smoothstep(0.06, 0.02, line) * step(len, 0.32);
	}
	glyph *= step(0.25, hash(id + 0.5));
	float band = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.92, UV.y);
	float edge = smoothstep(0.04, 0.0, abs(UV.y - 0.04)) + smoothstep(0.04, 0.0, abs(UV.y - 0.96));
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + UV.x * 12.0);
	ALBEDO = color.rgb * intensity * pulse;
	ALPHA = clamp((glyph * band + edge * 0.6) * reveal, 0.0, 1.0);
}
