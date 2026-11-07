// Contorno anime por casco invertido com espessura constante em pixels (estilo Storm).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 color : source_color = vec4(0.07, 0.035, 0.09, 1.0);
uniform float width = 0.006;      // compatibilidade: escala relativa
uniform float px = 2.3;           // espessura em pixels a 1080p
uniform float dissolve = 0.0;
void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * vp;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 nc = (PROJECTION_MATRIX * vec4(nv, 0.0)).xy;
	float l = length(nc);
	if (l > 0.0001) nc /= l;
	float dist = -vp.z;
	float w = px * (width / 0.006) * clamp(7.0 / max(dist, 0.1), 0.55, 1.15);
	clip.xy += nc * w * 2.0 / VIEWPORT_SIZE * clip.w * (VIEWPORT_SIZE.y / 1080.0);
	// empurra levemente para trás para não sobrepor o próprio modelo
	clip.z -= 0.00002 * clip.w;
	POSITION = clip;
}
void fragment() {
	if (dissolve > 0.6) discard;
	ALBEDO = color.rgb;
}
