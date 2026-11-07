// Corpo comum dos materiais de cenário cel-shaded (incluído por toon_world e toon_world_cut).
#include "res://shaders/toon_common.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_emis_tex = false;
uniform vec3 emission_col : source_color = vec3(0.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_cut = 0.5;
uniform float key_amt = 0.25;
uniform float saturate_amt = 1.05;

vec4 toon_world_albedo(vec2 uv) {
	vec2 u = uv * uv_scale.xy + uv_offset.xy;
	vec4 t = use_tex ? texture(albedo_tex, u) : vec4(1.0);
	vec4 c = t * albedo_col;
	// realça a saturação (cores "pintadas" de anime)
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = max(mix(vec3(l), c.rgb, saturate_amt), 0.0);
	return c;
}

vec3 toon_world_emission(vec2 uv, vec3 albedo, vec3 n, vec3 view) {
	vec2 u = uv * uv_scale.xy + uv_offset.xy;
	vec3 e = emission_col * (use_emis_tex ? texture(emission_tex, u).rgb : vec3(1.0));
	return e + toon_key_light(albedo, n, view) * key_amt;
}

// 3 tons: sombra colorida / meio-tom / luz. dir = LIGHT_IS_DIRECTIONAL.
vec3 toon_world_light(vec3 albedo, vec3 light_col, float att, float ndl, bool dir) {
	float sh = dir ? smoothstep(0.25, 0.45, att) : 1.0;
	float b1 = smoothstep(-0.02, 0.04, ndl) * sh;
	float b2 = smoothstep(0.42, 0.5, ndl) * sh;
	vec3 shade = mix(toon_shadow.rgb * 0.8, vec3(0.78), b1);
	shade = mix(shade, vec3(1.0), b2);
	float fall = dir ? 1.0 : toon_fall(att);
	return albedo * light_col * shade * fall;
}
