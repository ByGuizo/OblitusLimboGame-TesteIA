// O coração pulsante do Limbo
shader_type spatial;
uniform float pulse_speed = 2.6;
uniform vec3 vein_col : source_color = vec3(0.8, 0.15, 1.0);
uniform vec3 body_col : source_color = vec3(0.05, 0.0, 0.08);
uniform sampler2D skin_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_skin = false;
varying vec3 lp;
float hash(vec3 p) { vec3 p3 = fract(p * 0.1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }
float noise(vec3 p) { vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z); }
void vertex() {
	float beat = max(0.0, sin(TIME * pulse_speed)) * 0.06 + sin(TIME * 1.3) * 0.03;
	VERTEX += NORMAL * (sin(VERTEX.y * 1.5 + TIME * 2.0) * 0.35 + sin(VERTEX.x * 2.0 - TIME * 1.3) * 0.25 + beat * length(VERTEX));
	lp = VERTEX;
}
void fragment() {
	float n = noise(lp * 0.6 + vec3(0.0, TIME * 0.2, 0.0));
	float vein = pow(1.0 - abs(noise(lp * 0.9 + vec3(TIME * 0.1)) - 0.5) * 2.0, 10.0);
	ALBEDO = body_col * (0.5 + n);
	if (use_skin) {
		// projeção triplanar simples da textura orgânica
		vec3 w = abs(normalize(lp)); w /= (w.x + w.y + w.z);
		vec3 s = texture(skin_tex, lp.yz * 0.12).rgb * w.x + texture(skin_tex, lp.xz * 0.12).rgb * w.y + texture(skin_tex, lp.xy * 0.12).rgb * w.z;
		ALBEDO = s * 0.55 * (0.6 + n * 0.6);
	}
	ROUGHNESS = 0.35;
	EMISSION = vein_col * vein * (1.2 + 0.8 * max(0.0, sin(TIME * pulse_speed))) + vein_col * 0.16 * n;
}
