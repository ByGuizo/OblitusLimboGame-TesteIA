// Portal do ritual "Oblitus Limbo": vórtice vermelho com aro brilhante, sempre de frente
// para a câmera.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float open = 0.05;
uniform float t = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float sw = a * 3.0 + r * 14.0 - t * 3.0;
	float bands = 0.5 + 0.5 * sin(sw) * sin(sw * 0.5 + t);
	float inside = smoothstep(open, open - 0.06, r);
	float rim = exp(-pow((r - open * 0.97) * 16.0, 2.0));
	vec3 col = vec3(0.75, 0.02, 0.08) * bands * (1.0 - r / max(open, 0.001)) * 1.4;
	col *= smoothstep(0.0, 0.45 * open, r);
	col += vec3(2.6, 0.25, 0.45) * rim * 2.0;
	float alpha = clamp(max(inside, rim), 0.0, 1.0);
	ALBEDO = col;
	ALPHA = alpha;
}
