// Contornos de anime em tela: bordas por profundidade e normal (Sobel simplificado) sobre todo o
// cenário. Desenhado num quad preso à câmera, antes dos demais transparentes (partículas ficam por cima).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_col : source_color = vec4(0.07, 0.035, 0.1, 1.0);
uniform float thickness = 1.0;
uniform float strength = 0.85;
uniform float max_dist = 60.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// profundidade linear barata (projeção perspectiva: só a coluna z/w importa)
float lin_depth(vec2 uv, mat4 ip) {
	float d = texture(depth_tex, uv).r;
	return -(ip[2].z * d + ip[3].z) / (ip[2].w * d + ip[3].w);
}

vec3 nrm(vec2 uv) {
	return texture(nr_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = thickness * (VIEWPORT_SIZE.y / 1080.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = lin_depth(uv, INV_PROJECTION_MATRIX);
	if (d0 > max_dist * 3.0) discard;
	vec2 o[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	float dd = 0.0;
	for (int i = 0; i < 4; i++) {
		float di = lin_depth(uv + o[i], INV_PROJECTION_MATRIX);
		dd = max(dd, (d0 - di) / max(d0, 0.001));
	}
	// normais: só 2 amostras (direita e cima) e só perto da câmera
	float nd = 0.0;
	if (d0 < max_dist) {
		vec3 n0 = nrm(uv);
		float l0 = max(length(n0), 0.001);
		vec3 n1 = nrm(uv + o[0]);
		vec3 n2 = nrm(uv + o[2]);
		nd = max(1.0 - dot(n0, n1) / (l0 * max(length(n1), 0.001)), 1.0 - dot(n0, n2) / (l0 * max(length(n2), 0.001)));
	}
	// borda só do lado do objeto mais próximo (traço limpo, sem duplicar)
	float edge = max(smoothstep(0.035, 0.08, dd), smoothstep(0.3, 0.55, nd));
	float fade = 1.0 - smoothstep(max_dist * 0.6, max_dist, d0);
	float a = edge * fade * strength;
	if (a < 0.02) discard;
	ALBEDO = line_col.rgb;
	ALPHA = a;
}
