// Aura de poder estilo anime: casca inflada sobre a própria malha do personagem (material_overlay),
// com línguas de chama subindo pela silhueta. O miolo fica transparente.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, shadows_disabled, fog_disabled;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 col_a : source_color = vec3(1.0, 0.1, 0.15);
uniform vec3 col_b : source_color = vec3(1.0, 0.85, 0.6);
uniform float intensity = 2.2;
uniform float alpha = 1.0;
uniform float speed = 1.4;
uniform float grow = 0.05;
varying vec3 wpos;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise_tex, vec2(w.x * 0.9 + w.z * 0.7, w.y * 0.8 - TIME * speed)).r;
	VERTEX += NORMAL * grow * (0.6 + n * 1.4);
	// línguas puxadas para cima nas partes viradas para os lados
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0)) * n * n * grow * 1.6;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// cull_front: vemos a face de trás da casca, então a normal aponta para longe
	float fres = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	vec2 q = vec2(wpos.x * 1.3 + wpos.z * 1.1, wpos.y * 1.1);
	float n1 = texture(noise_tex, q * vec2(1.0, 0.6) - vec2(0.0, TIME * speed)).r;
	float n2 = texture(noise_tex, q * vec2(2.1, 1.3) + vec2(0.31, -TIME * speed * 1.8)).r;
	float flame = n1 * 0.6 + n2 * 0.4;
	float body = pow(fres, 0.8) * 1.2 + (flame - 0.5) * 1.1 - 0.42;
	float outer = smoothstep(0.0, 0.05, body);
	float inner = smoothstep(0.3, 0.36, body);
	ALBEDO = mix(col_a, col_b, inner) * intensity;
	float near = smoothstep(0.5, 1.4, -VERTEX.z);
	ALPHA = outer * alpha * near * (0.45 + inner * 0.55);
}
