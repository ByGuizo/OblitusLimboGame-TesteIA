// Cenário cel-shaded (opaco)
shader_type spatial;
render_mode cull_back;
#include "res://shaders/toon_world_body.gdshaderinc"

void fragment() {
	vec4 c = toon_world_albedo(UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = toon_world_emission(UV, c.rgb, NORMAL, VIEW);
}

void light() {
	DIFFUSE_LIGHT += toon_world_light(ALBEDO, LIGHT_COLOR, ATTENUATION, dot(NORMAL, LIGHT), LIGHT_IS_DIRECTIONAL);
}
