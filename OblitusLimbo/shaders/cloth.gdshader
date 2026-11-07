// Capas e panos: barra rasgada por ruído, dupla face, rampa
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
#include "res://shaders/toon_common.gdshaderinc"
uniform vec3 shade_tint : source_color = vec3(1.0);
uniform vec3 col : source_color = vec3(0.08);
uniform vec3 inner_col : source_color = vec3(0.05);
uniform sampler2D pattern : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_pattern = false;
uniform vec2 pattern_scale = vec2(2.0, 3.0);
uniform float tatter = 0.18;
uniform float tatter_freq = 9.0;
uniform vec3 trim_col : source_color = vec3(0.0);
uniform float trim = 0.0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float dissolve = 0.0;
uniform float fur = 0.0;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(float x) { float i = floor(x); float f = fract(x); return mix(hash(vec2(i, 3.1)), hash(vec2(i + 1.0, 3.1)), f * f * (3.0 - 2.0 * f)); }
void fragment() {
	// UV.y: 0 = ombros, 1 = barra
	float cut = 1.0 - tatter * (0.35 + 0.65 * noise(UV.x * tatter_freq * 3.0) * noise(UV.x * tatter_freq * 1.3 + 7.0));
	if (UV.y > cut) discard;
	if (dissolve > 0.0 && hash(floor(UV * 80.0)) < dissolve) discard;
	vec3 c = FRONT_FACING ? col : inner_col;
	if (use_pattern && !FRONT_FACING) c = texture(pattern, UV * pattern_scale).rgb;
	float folds = 0.86 + 0.14 * sin(UV.x * 40.0 + noise(UV.y * 6.0) * 4.0);
	c *= folds;
	c = mix(c, trim_col, trim * smoothstep(cut - 0.06, cut - 0.02, UV.y));
	if (fur > 0.0 && FRONT_FACING) c *= 0.82 + 0.18 * hash(floor(UV * vec2(140.0, 70.0)));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
	EMISSION = flash.rgb * flash.a + toon_key_light(c, FRONT_FACING ? NORMAL : -NORMAL, VIEW) * 0.8;
	ALBEDO *= shade_tint;
}
void light() {
	DIFFUSE_LIGHT += toon_diffuse(ALBEDO, LIGHT_COLOR, ATTENUATION, abs(dot(NORMAL, LIGHT)) * 0.9 + 0.05, 1.0, LIGHT_IS_DIRECTIONAL) * 0.9;
}
