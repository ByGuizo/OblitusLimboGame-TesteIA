// Iluminação anime compartilhada (estilo Storm): rampa de 2 tons com borda dura,
// sombra colorida, luz-chave fixa vinda da câmera e contraluz (rim) nítido.
// Parâmetros globais definidos por cenário (RenderingServer.global_shader_parameter_set).
global uniform vec4 toon_shadow;     // cor multiplicada na área de sombra
global uniform float toon_key;       // força da luz-chave de câmera (deixa os personagens legíveis à noite)
global uniform vec4 toon_key_col;
global uniform vec4 toon_rim_col;
global uniform float toon_rim;

// Queda de luz pontual em degraus (anime), respeitando o alcance real da luz.
float toon_fall(float att) {
	return smoothstep(0.0, 0.04, att) * 0.18 + smoothstep(0.1, 0.18, att) * 0.25 + smoothstep(0.38, 0.5, att) * 0.3;
}

// Contribuição difusa toon para um light(). dir = LIGHT_IS_DIRECTIONAL.
vec3 toon_diffuse(vec3 albedo, vec3 light_col, float att, float ndl, float floor_amt, bool dir) {
	float sh = dir ? smoothstep(0.25, 0.45, att) : 1.0;
	float b = smoothstep(-0.015, 0.035, ndl) * sh;
	float fall = dir ? 1.0 : toon_fall(att);
	vec3 shade = mix(toon_shadow.rgb * floor_amt, vec3(1.0), b);
	return albedo * light_col * shade * fall;
}

// Luz-chave fixa de câmera + rim light (somar em EMISSION no fragment; n = NORMAL em espaço de visão).
vec3 toon_key_light(vec3 albedo, vec3 n, vec3 view) {
	vec3 kd = normalize(vec3(-0.45, 0.55, 0.7));
	float k = smoothstep(-0.05, 0.05, dot(n, kd));
	// preenchimento: forte o bastante para ler a silhueta à noite, sem estourar onde já há luz
	vec3 key = albedo * toon_key_col.rgb * toon_key * mix(toon_shadow.rgb * 0.5, vec3(0.8), k);
	float fres = 1.0 - clamp(dot(n, view), 0.0, 1.0);
	float rim = smoothstep(0.62, 0.72, fres) * smoothstep(-0.2, 0.3, -n.x * 0.6 + n.y * 0.4);
	return key + toon_rim_col.rgb * rim * toon_rim * (0.35 + 0.65 * clamp(dot(albedo, vec3(0.5)), 0.0, 1.0));
}
