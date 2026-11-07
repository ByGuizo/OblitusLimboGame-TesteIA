// Cabeça anime: pele em rampa + rosto pintado projetado na frente
shader_type spatial;
render_mode cull_back;
#include "res://shaders/toon_common.gdshaderinc"
uniform vec3 shade_tint : source_color = vec3(1.0);
uniform vec3 skin_col : source_color = vec3(0.95, 0.78, 0.68);
uniform sampler2D face_tex : source_color, hint_default_transparent, filter_linear_mipmap;
uniform sampler2D face_tex2 : source_color, hint_default_transparent, filter_linear_mipmap;
uniform float face_mix = 0.0;
uniform vec2 face_size = vec2(0.24, 0.24);
uniform vec2 face_center = vec2(0.0, 0.0);
uniform vec3 blush_col : source_color = vec3(1.0, 0.45, 0.45);
uniform float blush = 0.15;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec3 eye_glow : source_color = vec3(0.0);
uniform float dissolve = 0.0;
uniform float shade_floor = 0.42;
varying vec3 lpos;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void vertex() { lpos = VERTEX; }
void fragment() {
	vec2 fuv = vec2(0.5 + (lpos.x - face_center.x) / face_size.x, 0.5 - (lpos.y - face_center.y) / face_size.y);
	vec4 f = vec4(0.0);
	if (lpos.z > 0.0 && fuv.x > 0.0 && fuv.x < 1.0 && fuv.y > 0.0 && fuv.y < 1.0) {
		f = mix(texture(face_tex, fuv), texture(face_tex2, fuv), face_mix);
	}
	vec3 c = skin_col;
	float ck = smoothstep(0.12, 0.0, length(vec2(abs(lpos.x) - 0.045, lpos.y + 0.012) * vec2(1.0, 1.6)));
	c = mix(c, blush_col, ck * blush * step(0.0, lpos.z));
	c = mix(c, f.rgb, f.a);
	if (dissolve > 0.0 && hash(floor(fuv * 90.0)) < dissolve) discard;
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.0;
	float sat = max(max(f.r, f.g), f.b) - min(min(f.r, f.g), f.b);
	EMISSION = eye_glow * f.a * smoothstep(0.35, 0.6, sat) + flash.rgb * flash.a;
	EMISSION += toon_key_light(c, NORMAL, VIEW) * shade_tint * 0.9;
	ALBEDO *= shade_tint;
}
void light() {
	// rosto de anime: sombra só nas laterais, frente sempre limpa
	float ndl = dot(NORMAL, LIGHT) * 0.6 + 0.45;
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.333))), 0.3);
	DIFFUSE_LIGHT += toon_diffuse(ALBEDO, lc, ATTENUATION, ndl, 1.2, LIGHT_IS_DIRECTIONAL) * 0.8;
}
