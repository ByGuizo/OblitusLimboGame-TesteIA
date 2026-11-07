// Processo de partículas emitidas manualmente: CUSTOM = (vida, idade, tamanho, giro)
shader_type particles;
uniform float gravity = 0.0;
uniform float drag = 1.0;
uniform float size_end = 0.3;
uniform float spin = 0.0;
uniform float turbulence = 0.0;

void start() {
	if (!RESTART_CUSTOM) {
		CUSTOM = vec4(1.0, 0.0, 0.1, 0.0);
	}
	CUSTOM.y = 0.0;
}

void process() {
	CUSTOM.y += DELTA;
	float life = max(CUSTOM.x, 0.01);
	float f = CUSTOM.y / life;
	if (f >= 1.0) {
		ACTIVE = false;
	}
	VELOCITY.y -= gravity * DELTA;
	VELOCITY *= max(0.0, 1.0 - drag * DELTA);
	if (turbulence > 0.0) {
		vec3 p = TRANSFORM[3].xyz;
		VELOCITY += vec3(sin(p.y * 3.1 + TIME * 2.0), 0.0, cos(p.x * 2.7 + TIME * 1.7)) * turbulence * DELTA;
	}
	vec3 pos = TRANSFORM[3].xyz + VELOCITY * DELTA;
	float s = CUSTOM.z * mix(1.0, size_end, f);
	float a = CUSTOM.w + spin * CUSTOM.y;
	TRANSFORM = mat4(vec4(cos(a) * s, sin(a) * s, 0.0, 0.0), vec4(-sin(a) * s, cos(a) * s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(pos, 1.0));
}
