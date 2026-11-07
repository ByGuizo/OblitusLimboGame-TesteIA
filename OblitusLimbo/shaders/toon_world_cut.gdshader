// Cenário cel-shaded com recorte (folhagem, grades, bandeiras): dupla face + alpha scissor
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/toon_world_body.gdshaderinc"

void fragment() {
	vec4 c = toon_world_albedo(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = toon_world_emission(UV, c.rgb, FRONT_FACING ? NORMAL : -NORMAL, VIEW);
	BACKLIGHT = c.rgb * 0.25;
}

void light() {
	DIFFUSE_LIGHT += toon_world_light(ALBEDO, LIGHT_COLOR, ATTENUATION, abs(dot(NORMAL, LIGHT)) * 0.85 + 0.1, LIGHT_IS_DIRECTIONAL);
}
