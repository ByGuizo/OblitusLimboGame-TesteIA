// Céu anime: gradiente pintado, nuvens de borda definida em 2 camadas (com borda iluminada pela lua),
// estrelas cintilantes e lua com halo. mode 1 = Limbo (veias pulsantes), cores parametrizadas.
shader_type sky;
uniform int mode = 0;
uniform vec3 top_col : source_color = vec3(0.01, 0.015, 0.05);
uniform vec3 horizon_col : source_color = vec3(0.07, 0.09, 0.2);
uniform vec3 bottom_col : source_color = vec3(0.01, 0.01, 0.02);
uniform vec3 moon_dir = vec3(-0.35, 0.55, 0.75);
uniform vec3 moon_col : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_size = 0.035;
uniform float star_amount = 1.0;
uniform float cloud_amount = 0.5;
uniform vec3 cloud_col : source_color = vec3(0.12, 0.12, 0.26);
uniform vec3 cloud_lit_col : source_color = vec3(0.55, 0.5, 0.85);
uniform float vein_amount = 1.0;
uniform vec3 vein_col : source_color = vec3(0.75, 0.15, 0.95);
uniform vec3 vein_base : source_color = vec3(0.07, 0.01, 0.12);

float hash(vec3 p) { vec3 p3 = fract(p * 0.1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += noise(p) * a; p *= 2.02; a *= 0.5; } return s; }

// camada de nuvem anime: devolve (cobertura, iluminação da borda)
vec2 cloud_layer(vec3 d, float scale, float speed, float thr, vec3 md) {
	vec2 uv = d.xz / (d.y + 0.18) * scale;
	vec3 p = vec3(uv.x + TIME * speed, uv.y, 0.0);
	float n = fbm(p);
	float cov = smoothstep(thr, thr + 0.025, n);
	// borda iluminada: amostra deslocada na direção da lua
	vec2 off = normalize(md.xz + 0.0001) * 0.06;
	float n2 = fbm(vec3(uv.x - off.x + TIME * speed, uv.y - off.y, 0.0));
	float rim = cov * (1.0 - smoothstep(thr, thr + 0.05, n2));
	return vec2(cov, rim);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 c = mix(horizon_col, top_col, smoothstep(0.0, 0.55, h));
	c = mix(c, bottom_col, smoothstep(0.0, -0.3, h));
	// faixa clara no horizonte (céu pintado)
	c += horizon_col * 0.35 * exp(-abs(h) * 14.0);
	if (mode == 0) {
		vec3 md = normalize(moon_dir);
		float md_dot = dot(d, md);
		if (!AT_CUBEMAP_PASS) {
			vec3 sp = floor(d * 380.0);
			float st = step(0.9965, hash(sp)) * smoothstep(0.02, 0.4, h);
			st *= 0.55 + 0.45 * sin(TIME * 2.0 + hash(sp + 1.0) * 40.0);
			float big = step(0.99985, hash(floor(d * 120.0))) * smoothstep(0.1, 0.5, h);
			c += vec3(0.85, 0.9, 1.0) * (st + big * 2.0) * star_amount;
		}
		// lua com halo largo de anime
		float disc = smoothstep(1.0 - moon_size * 0.06, 1.0 - moon_size * 0.05, md_dot);
		float crater = AT_CUBEMAP_PASS ? 0.0 : fbm(d * 60.0) * 0.2 * disc;
		c = mix(c, moon_col * (1.0 - crater) * 2.2, disc);
		c += moon_col * (pow(max(md_dot, 0.0), 260.0) * 0.7 + pow(max(md_dot, 0.0), 24.0) * 0.12 + pow(max(md_dot, 0.0), 4.0) * 0.04);
		if (h > -0.02 && cloud_amount > 0.0) {
			float fade = smoothstep(-0.02, 0.12, h);
			vec2 far = cloud_layer(d, 1.2, 0.004, 0.56, md);
			vec2 nearc = cloud_layer(d, 0.7, 0.009, 0.6, md);
			float glow = pow(max(md_dot, 0.0), 6.0);
			vec3 cfar = mix(cloud_col * 0.8, cloud_lit_col, far.y * (0.4 + glow));
			vec3 cnear = mix(cloud_col, cloud_lit_col * 1.2, nearc.y * (0.5 + glow * 1.5));
			c = mix(c, cfar, far.x * fade * cloud_amount * 0.85);
			c = mix(c, cnear, nearc.x * fade * cloud_amount);
		}
	} else {
		float n = fbm(d * 2.5 + vec3(0.0, TIME * 0.02, 0.0));
		float vein = pow(1.0 - abs(fbm(d * 3.5 + vec3(TIME * 0.01)) - 0.5) * 2.0, 14.0);
		float pulse = 0.7 + 0.3 * sin(TIME * 1.3);
		vec3 lc = vein_base + vein_base * 2.5 * n + vein_col * vein * pulse;
		c = mix(c + vein_col * vein * 0.25 * vein_amount + vein_base * n, lc, step(0.99, vein_amount));
	}
	COLOR = c;
}
