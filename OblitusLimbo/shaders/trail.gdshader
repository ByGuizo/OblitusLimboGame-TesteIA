// Rastro de arma em fita (UV.x = idade 0 nova..1 velha, UV.y = base..ponta).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled, fog_disabled;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 color : source_color = vec3(0.7, 0.85, 1.0);
uniform vec3 core : source_color = vec3(1.0);
uniform float intensity = 2.4;
void fragment() {
	float age = UV.x;
	float tip = UV.y;
	float n = texture(noise_tex, vec2(age * 2.0 + TIME * 3.0, tip * 0.7)).r;
	// borda erodida conforme envelhece (traço de anime)
	float m = smoothstep(age * 0.9 - 0.05, age * 0.9, n * 0.85 + tip * 0.35);
	float c = smoothstep(0.75, 0.95, tip) * (1.0 - age);
	ALBEDO = mix(color, core, c) * intensity;
	ALPHA = m * (1.0 - age) * smoothstep(0.0, 0.25, tip);
}
