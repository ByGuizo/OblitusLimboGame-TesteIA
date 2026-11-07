// Capim (malhas do Stylized Nature) com vento e gradiente da base às pontas.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/toon_world_body.gdshaderinc"
uniform vec3 base_col : source_color = vec3(0.07, 0.1, 0.05);
uniform vec3 mid_col : source_color = vec3(0.18, 0.24, 0.1);
uniform vec3 tip_col : source_color = vec3(0.6, 0.25, 0.75);
uniform float height = 1.6;
uniform float sway = 0.18;
uniform float tip_start = 0.6;
uniform float emission_tip = 0.0;
varying float h;
void vertex() {
	h = clamp(VERTEX.y / height, 0.0, 1.0);
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = h * h;
	VERTEX.x += sin(TIME * 1.6 + w.x * 0.4 + w.z * 0.3) * sway * k;
	VERTEX.z += cos(TIME * 1.3 + w.x * 0.3) * sway * 0.5 * k;
}
void fragment() {
	vec3 c = mix(base_col, mid_col, smoothstep(0.0, 0.5, h));
	c = mix(c, tip_col, smoothstep(tip_start, 1.0, h));
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
	EMISSION = tip_col * smoothstep(0.75, 1.0, h) * emission_tip;
	BACKLIGHT = vec3(0.25);
}

void light() {
	DIFFUSE_LIGHT += toon_world_light(ALBEDO, LIGHT_COLOR, ATTENUATION, abs(dot(NORMAL, LIGHT)) * 0.7 + 0.25, LIGHT_IS_DIRECTIONAL);
}
