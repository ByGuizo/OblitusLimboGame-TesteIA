// Sprite de efeito (billboard ou plano) com textura, cor e alfa animados por código.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_add;
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 2.5;
uniform float alpha = 1.0;
uniform bool billboard = true;
uniform float rot = 0.0;
void vertex() {
	if (billboard) {
		mat4 mm = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		float s = length(MODEL_MATRIX[0].xyz);
		mm = mm * mat4(vec4(cos(rot) * s, sin(rot) * s, 0.0, 0.0), vec4(-sin(rot) * s, cos(rot) * s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mm;
	}
}
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = color.rgb * t.rgb * intensity;
	ALPHA = t.a * color.a * alpha;
}
