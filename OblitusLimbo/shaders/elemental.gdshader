// Criatura Mutável: 0 = água, 1 = vento, 2 = fogo (rocha com lava)
shader_type spatial;
render_mode cull_back, depth_draw_always;
uniform int form = 0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float dissolve = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
varying vec3 wpos;

float hash3(vec3 p) { vec3 p3 = fract(p * 0.1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { s += noise3(p) * a; p *= 2.03; a *= 0.5; } return s; }

void vertex() {
	float t = TIME;
	if (form == 0) VERTEX += NORMAL * (sin(VERTEX.y * 18.0 + t * 6.0) * cos(VERTEX.x * 14.0 + t * 4.0)) * 0.012;
	if (form == 1) VERTEX += NORMAL * sin(VERTEX.y * 10.0 - t * 9.0 + atan(VERTEX.x, VERTEX.z) * 3.0) * 0.015;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float t = TIME;
	if (form == 0) {
		float caust = fbm(wpos * 2.5 + vec3(0.0, t * 0.8, t * 0.5));
		vec2 off = NORMAL.xy * 0.045 + (vec2(caust, fbm(wpos * 3.0 + vec3(t))) - 0.5) * 0.03;
		vec3 behind = texture(screen_tex, SCREEN_UV + off).rgb;
		ALBEDO = vec3(0.02, 0.07, 0.14);
		ROUGHNESS = 0.05;
		SPECULAR = 0.9;
		EMISSION = behind * vec3(0.45, 0.75, 1.0) * 0.85 + vec3(0.15, 0.5, 1.0) * fres * 1.1 + vec3(0.4, 0.75, 1.0) * pow(caust, 4.0) * 0.6;
	} else if (form == 1) {
		float sw = fbm(vec3(wpos.x * 1.5 + t * 1.2, wpos.y * 3.0 - t * 2.5, wpos.z * 1.5));
		vec2 off = NORMAL.xy * 0.02 + vec2(sin(wpos.y * 6.0 - t * 8.0), 0.0) * 0.012;
		vec3 behind = texture(screen_tex, SCREEN_UV + off).rgb;
		float streak = smoothstep(0.55, 0.78, sw);
		ALBEDO = vec3(0.0);
		ROUGHNESS = 0.6;
		EMISSION = behind * 0.92 + vec3(0.75, 0.85, 1.0) * (fres * 0.7 + streak * 0.55);
	} else {
		float n = fbm(wpos * 1.8);
		float crack = abs(fbm(wpos * 1.2 + vec3(7.0)) - 0.5);
		float glow = smoothstep(0.06, 0.0, crack);
		float pulse = 0.75 + 0.25 * sin(t * 3.0 + wpos.y * 2.0);
		ALBEDO = mix(vec3(0.09, 0.07, 0.06), vec3(0.22, 0.15, 0.1), n);
		ALPHA = 1.0;
		ROUGHNESS = 0.9;
		EMISSION = vec3(1.0, 0.38, 0.06) * glow * 4.0 * pulse + vec3(1.0, 0.3, 0.05) * fres * 0.6;
	}
	if (dissolve > 0.0 && hash3(floor(wpos * 20.0)) < dissolve) discard;
	EMISSION += flash.rgb * flash.a;
}
