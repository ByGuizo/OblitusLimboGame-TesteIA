// Gradação de tela: Apagão (vermelho e preto), memória (sépia), Manifestação (ciano-dourado),
// dano (vinheta vermelha + aberração), flash e granulação.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float hurt = 0.0;
uniform float red = 0.0;
uniform float desat = 0.0;
uniform float flash = 0.0;
uniform float harm = 0.0;
uniform float vig = 0.0;
uniform float time = 0.0;
uniform float grain = 1.0;
uniform float impact = 0.0;
uniform float purple_tone = 0.12;
uniform float anime_sat = 1.12;
uniform float impact_frame = 0.0;     // 1 = quadro de impacto invertido (preto e branco)
uniform vec3 impact_col : source_color = vec3(0.92, 0.88, 1.0);
uniform float speed_lines = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);
	float ca = 0.0008 + hurt * 0.006 + red * 0.004 + impact * 0.012;
	vec3 col = vec3(texture(screen_tex, uv + c * ca).r, texture(screen_tex, uv).g, texture(screen_tex, uv - c * ca).b);
	if (impact > 0.01) {
		// desfoque radial a partir do centro (golpes pesados / finalizadores)
		vec3 acc = col;
		for (int i = 1; i <= 6; i++) {
			acc += texture(screen_tex, uv - c * (float(i) * 0.012 * impact)).rgb;
		}
		col = mix(col, acc / 7.0, clamp(impact, 0.0, 1.0) * smoothstep(0.05, 0.45, d));
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	// grade de anime: saturação + sombras puxadas para violeta, luzes levemente quentes
	col = max(mix(vec3(l), col, anime_sat), 0.0);
	float shadow_w = 1.0 - smoothstep(0.0, 0.45, l);
	col = mix(col, col * vec3(0.82, 0.66, 1.18) + vec3(0.025, 0.0, 0.045), purple_tone * shadow_w);
	col = mix(col, col * vec3(1.04, 1.0, 0.96), smoothstep(0.6, 1.0, l) * 0.5);
	l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 sep = vec3(l * 1.08, l * 0.98, l * 0.82);
	col = mix(col, sep, desat);
	vec3 rd = vec3(pow(max(l, 0.0), 0.8) * 1.7, l * 0.1, l * 0.12);
	col = mix(col, rd, red * 0.62);
	col += vec3(0.03, 0.06, 0.07) * harm + vec3(0.05, 0.03, 0.0) * harm * l;
	float v = smoothstep(0.95, 0.25, d * (1.0 + vig + red * 0.7 + hurt * 0.6 + desat * 0.5));
	col *= mix(0.3, 1.0, v);
	col = mix(col, vec3(0.55, 0.0, 0.02), hurt * 0.3 * (1.0 - v));
	vec2 gp = floor(uv * vec2(960.0, 540.0)) + fract(time * 13.7) * 91.0;
	vec3 p3 = fract(vec3(gp.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	float n = fract((p3.x + p3.y) * p3.z);
	col += (n - 0.5) * (0.018 + desat * 0.05) * grain;
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
	// linhas de velocidade radiais (avanços e Ultimates)
	if (speed_lines > 0.01) {
		float ang = atan(c.y, c.x);
		float id = floor(ang * 70.0 + floor(time * 18.0) * 13.0);
		vec3 q3 = fract(vec3(id, id * 1.7, id * 3.1) * 0.1031);
		q3 += dot(q3, q3.yzx + 33.33);
		float rnd = fract((q3.x + q3.y) * q3.z);
		float line = step(0.82, rnd) * smoothstep(0.22 + rnd * 0.15, 0.55, d);
		col = mix(col, vec3(1.0), line * speed_lines * 0.85);
	}
	// quadro de impacto: silhuetas escuras sobre fundo claro (estilo mangá)
	if (impact_frame > 0.5) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		float ink = smoothstep(0.16, 0.24, lum);
		col = mix(vec3(0.03, 0.0, 0.06), impact_col, 1.0 - ink);
	}
	COLOR = vec4(col, 1.0);
}
