// Personagens: PBR texturizado com sombreamento em rampa (anime), recoloração por matiz,
// pele tingível, flash de impacto e dissolução.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
#include "res://shaders/toon_common.gdshaderinc"

uniform vec3 shade_tint : source_color = vec3(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal = false;
uniform vec3 tint = vec3(1.0);
uniform float saturation = 1.0;
uniform float brightness = 1.0;
// trocas de cor: x = matiz central (0-1), y = largura, z = saturação mínima, w = força
uniform vec4 swap1 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec3 swap1_col : source_color = vec3(1.0);
uniform vec4 swap2 = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec3 swap2_col : source_color = vec3(1.0);
// troca dos tons claros sem saturação (camisas, panos brancos)
uniform float light_swap = 0.0;
uniform vec3 light_swap_col : source_color = vec3(1.0);
uniform bool skin_mode = false;
uniform vec3 skin_col : source_color = vec3(0.9, 0.7, 0.6);
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec3 emission_col : source_color = vec3(0.0);
uniform float rim_strength = 1.0;
uniform vec3 rim_col : source_color = vec3(0.75, 0.82, 1.0);
uniform float dissolve = 0.0;
uniform float roughness_v = 0.8;
uniform float shade_floor = 0.42;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
float hue_w(float h, vec4 s) {
	float dh = abs(fract(h - s.x + 0.5) - 0.5);
	return s.w * (1.0 - smoothstep(s.y * 0.6, s.y, dh));
}
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 c = tex.rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	if (skin_mode) {
		c = skin_col * mix(0.82, 1.0, clamp(lum * 1.4, 0.0, 1.0));
	} else {
		vec3 hsv = rgb2hsv(c);
		float w1 = hue_w(hsv.x, swap1) * smoothstep(swap1.z, swap1.z + 0.08, hsv.y);
		float w2 = hue_w(hsv.x, swap2) * smoothstep(swap2.z, swap2.z + 0.08, hsv.y);
		float shade = clamp(hsv.z / 0.55, 0.25, 1.6);
		c = mix(c, swap1_col * shade, w1);
		c = mix(c, swap2_col * shade, w2);
		float wl = light_swap * smoothstep(0.45, 0.65, hsv.z) * (1.0 - smoothstep(0.12, 0.3, hsv.y));
		c = mix(c, light_swap_col * clamp(hsv.z / 0.75, 0.5, 1.3), wl);
		float l2 = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(l2), c, saturation) * tint;
	}
	c *= brightness;
	if (dissolve > 0.0) {
		float n = hash(floor(UV * 180.0));
		if (n < dissolve) discard;
		if (n < dissolve + 0.06) { EMISSION = vec3(2.0, 0.4, 0.8); }
	}
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	if (use_normal) { NORMAL_MAP = texture(normal_tex, UV).rgb; NORMAL_MAP_DEPTH = 0.8; }
	EMISSION += emission_col + toon_key_light(c, NORMAL, VIEW) * shade_tint * rim_strength + flash.rgb * flash.a;
	ALBEDO *= shade_tint;
}

void light() {
	DIFFUSE_LIGHT += toon_diffuse(ALBEDO, LIGHT_COLOR, ATTENUATION, dot(NORMAL, LIGHT), 1.0, LIGHT_IS_DIRECTIONAL) * 0.9;
}
