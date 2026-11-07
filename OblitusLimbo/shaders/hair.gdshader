// Cabelo anime: rampa, brilho em faixa e gradiente até as pontas
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/toon_common.gdshaderinc"
uniform vec3 shade_tint : source_color = vec3(1.0);
uniform vec3 base_col : source_color = vec3(0.9);
uniform vec3 tip_col : source_color = vec3(0.9);
uniform vec3 shine_col : source_color = vec3(1.0);
uniform float shine = 0.35;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float dissolve = 0.0;
uniform float shade_floor = 0.38;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void fragment() {
	// UV.y = 0 na raiz, 1 na ponta
	vec3 c = mix(base_col, tip_col, smoothstep(0.2, 1.0, UV.y));
	c *= mix(0.78, 1.0, 1.0 - abs(UV.x - 0.5) * 2.0);
	if (dissolve > 0.0 && hash(floor(UV * 60.0)) < dissolve) discard;
	ALBEDO = c;
	ROUGHNESS = 0.5;
	SPECULAR = 0.0;
	// faixa de brilho de anime: anel claro perto da raiz, nos fios voltados para a câmera
	float band = smoothstep(0.8, 0.95, abs(dot(NORMAL, VIEW))) * smoothstep(0.1, 0.18, UV.y) * (1.0 - smoothstep(0.3, 0.38, UV.y));
	EMISSION = shine_col * band * shine * 0.3 * (0.3 + c * 0.5) + toon_key_light(c, NORMAL, VIEW) * 0.7 + flash.rgb * flash.a;
	ALBEDO *= shade_tint;
}
void light() {
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.333))), 0.5);
	DIFFUSE_LIGHT += toon_diffuse(ALBEDO, lc, ATTENUATION, dot(NORMAL, LIGHT), 1.0, LIGHT_IS_DIRECTIONAL) * 0.78;
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.93, 0.98, abs(dot(NORMAL, h))) * 0.08;
}
