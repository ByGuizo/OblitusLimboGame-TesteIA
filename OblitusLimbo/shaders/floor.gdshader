// Chãos procedurais. mode 0 = terra/grama, 1 = mármore negro polido com mosaico rúnico,
// 2 = pedra do Limbo pulsante
shader_type spatial;
#include "res://shaders/toon_world_body.gdshaderinc"
uniform int mode = 0;
uniform vec3 col_a : source_color = vec3(0.12, 0.09, 0.06);
uniform vec3 col_b : source_color = vec3(0.1, 0.16, 0.06);
uniform vec3 col_c : source_color = vec3(0.3, 0.05, 0.4);
uniform float scale = 0.15;
uniform float rune_radius = 4.5;
uniform vec3 rune_col : source_color = vec3(0.7, 0.55, 0.2);
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_ground = false;
uniform float tex_scale = 0.25;
uniform vec3 ground_tint : source_color = vec3(1.0);
varying vec3 wp;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += noise(p) * a; p *= 2.03; a *= 0.5; } return s; }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	if (mode == 0) {
		float n = fbm(p * scale);
		float m = fbm(p * scale * 6.0 + 3.0);
		float g = smoothstep(0.4, 0.62, n);
		vec3 c = mix(col_a, col_b, g) * (0.75 + m * 0.5);
		c = mix(c, col_c, smoothstep(0.7, 0.85, fbm(p * scale * 2.0 + 9.0)) * 0.25);
		if (use_ground) {
			// textura pintada + variação em macroescala para esconder a repetição
			vec2 r = vec2(fbm(p * 0.05), fbm(p * 0.05 + 7.0)) * 0.6;
			vec3 t = texture(ground_tex, p * tex_scale + r).rgb;
			vec3 t2 = texture(ground_tex, p * tex_scale * 0.43 + vec2(0.37, 0.71)).rgb;
			t = mix(t, t2, smoothstep(0.35, 0.65, fbm(p * 0.08 + 3.0)));
			c = t * ground_tint * (0.75 + n * 0.5);
		}
		ALBEDO = c;
		ROUGHNESS = 0.95;
		SPECULAR = 0.1;
	} else if (mode == 1) {
		float n = fbm(p * 0.12);
		float vein = pow(1.0 - abs(sin((p.x * 0.4 + p.y * 0.25 + n * 6.0) * 3.1)), 18.0);
		float v2 = pow(1.0 - abs(sin((p.x * 0.17 - p.y * 0.44 + n * 4.0) * 5.0)), 30.0);
		vec2 tile = abs(fract(p / 2.0) - 0.5);
		float grout = step(0.485, max(tile.x, tile.y));
		vec3 c = vec3(0.025, 0.025, 0.035) + vec3(0.5, 0.52, 0.6) * (vein * 0.5 + v2 * 0.25) * (0.5 + n);
		c = mix(c, vec3(0.005), grout);
		// mosaico rúnico central
		float r = length(p);
		float ring = smoothstep(0.06, 0.0, abs(r - rune_radius)) + smoothstep(0.04, 0.0, abs(r - rune_radius * 0.92)) + smoothstep(0.05, 0.0, abs(r - rune_radius * 0.45));
		float ang = atan(p.y, p.x);
		float glyph = step(0.5, hash(vec2(floor(ang * 14.0), floor(r * 4.0)))) * step(rune_radius * 0.93, r) * step(r, rune_radius * 0.99) * step(0.3, fract(ang * 14.0 / 6.2831 * 6.0));
		float star = smoothstep(0.05, 0.0, abs(sin(ang * 3.0) * r - 0.0)) * step(r, rune_radius * 0.9) * 0.0;
		c = mix(c, rune_col, clamp(ring + glyph * 0.8, 0.0, 1.0));
		ALBEDO = c;
		ROUGHNESS = mix(0.08, 0.5, grout);
		METALLIC = 0.2;
		SPECULAR = 0.7;
	} else {
		float n = fbm(p * 0.3);
		float vein = pow(1.0 - abs(fbm(p * 0.5 + TIME * 0.05) - 0.5) * 2.0, 12.0);
		ALBEDO = vec3(0.05, 0.03, 0.08) * (0.6 + n);
		if (use_ground) {
			ALBEDO = texture(ground_tex, p * tex_scale).rgb * ground_tint * (0.7 + n * 0.5);
		}
		ROUGHNESS = 0.9;
		EMISSION = rune_col * vein * (0.6 + 0.4 * sin(TIME * 2.6));
	}
}

void light() {
	DIFFUSE_LIGHT += toon_world_light(ALBEDO, LIGHT_COLOR, ATTENUATION, dot(NORMAL, LIGHT), LIGHT_IS_DIRECTIONAL);
}
