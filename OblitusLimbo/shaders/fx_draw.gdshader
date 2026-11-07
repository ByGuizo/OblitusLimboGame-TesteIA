// Desenho das partículas (billboard). Cor inicial = COLOR, final = COLOR * end_mul.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec3 end_mul = vec3(1.0);
uniform float intensity = 2.0;
uniform float soft_fade = 0.12;
varying float f;
uniform int flip = 1;
vec2 flip_uv(vec2 uv, float life_f) {
	if (flip <= 1) return uv;
	float frames = float(flip * flip);
	float fr = min(floor(life_f * frames), frames - 1.0);
	vec2 cell = vec2(mod(fr, float(flip)), floor(fr / float(flip)));
	return (uv + cell) / float(flip);
}

void vertex() {
	mat4 mm = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mm = mm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mm;
	f = clamp(INSTANCE_CUSTOM.y / max(INSTANCE_CUSTOM.x, 0.01), 0.0, 1.0);
}
void fragment() {
	vec4 t = texture(tex, flip_uv(UV, f));
	vec3 c = COLOR.rgb * mix(vec3(1.0), end_mul, f);
	float fade = flip > 1 ? 1.0 : (1.0 - f * f);
	float a = t.a * COLOR.a * min(1.0, f / max(soft_fade, 0.001)) * fade;
	ALBEDO = c * t.rgb * intensity;
	ALPHA = a;
}
