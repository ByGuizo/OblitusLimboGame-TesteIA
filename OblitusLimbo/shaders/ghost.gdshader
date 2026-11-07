// Imagem residual (afterimage) de anime: silhueta translúcida colorida com borda forte.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(0.6, 0.3, 1.0);
uniform float alpha = 1.0;
void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color * (0.25 + smoothstep(0.35, 0.75, fres) * 1.6);
	ALPHA = alpha;
}
