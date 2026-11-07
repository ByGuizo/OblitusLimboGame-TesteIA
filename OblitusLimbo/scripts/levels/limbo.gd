extends LevelBase
## O Limbo — plataforma suspensa no vazio, ilhas de pedra flutuantes, o coração pulsante e o
## olho da Presença.

var rng := RandomNumberGenerator.new()
var heart: MeshInstance3D
var eye: Node3D
var slit: MeshInstance3D
var red: OmniLight3D
var islands: Array = []

func build() -> void:
	level_name = "limbo"
	surface = "stone"
	rng.seed = 666
	var AR := 1.85 if LevelBase.arena else 1.0    # arena do Versus: plataforma maior
	bounds = {"type": "circle", "r": 5.5 * AR, "c": Vector2.ZERO}
	cam_extra = 3.0
	spawn = {"pos": Vector3.ZERO, "yaw": 0.0}
	setup_env({"sky_mode": 1, "top": Color(0.04, 0.0, 0.07), "horizon": Color(0.2, 0.04, 0.32), "bottom": Color(0.015, 0.0, 0.03),
		"vein_col": Color(0.78, 0.2, 1.0), "vein_base": Color(0.06, 0.01, 0.12),
		"ambient": Color(0.42, 0.22, 0.62), "ambient_energy": 0.75, "fog": Color(0.09, 0.02, 0.16), "fog_density": 0.03,
		"vol_density": 0.03, "vol_albedo": Color(0.55, 0.3, 0.9), "vol_emission": Color(0.025, 0.0, 0.05), "vol_ambient": 0.3,
		"sun": 0.55, "sun_col": Color(0.78, 0.5, 1.0), "sun_rot": Vector3(-35, 180, 0), "exposure": 1.0, "glow": 1.1, "fog_sky": 0.3,
		"purple": 0.45, "toon_shadow": Color(0.45, 0.3, 0.75), "toon_key": 0.4, "toon_rim_col": Color(0.85, 0.5, 1.0), "toon_rim": 0.5})
	floor_collider()
	# plataforma
	var plat := CylinderMesh.new(); plat.top_radius = 6.0 * AR; plat.bottom_radius = 2.6 * AR; plat.height = 2.6; plat.radial_segments = 9; plat.rings = 2
	var floor_m := ShaderMaterial.new()
	floor_m.shader = preload("res://shaders/floor.gdshader")
	floor_m.set_shader_parameter("mode", 2)
	floor_m.set_shader_parameter("rune_col", Color(0.7, 0.2, 1.0))
	floor_m.set_shader_parameter("use_ground", true)
	floor_m.set_shader_parameter("ground_tex", load("res://assets/textures/limbo_ground.png"))
	floor_m.set_shader_parameter("tex_scale", 0.18)
	floor_m.set_shader_parameter("ground_tint", Color(0.55, 0.45, 0.7))
	prim(plat, floor_m, Vector3(0, -1.3, 0))
	for i in 7:
		var a := i * TAU / 7.0 + 0.3
		putk("nature", "Rock_Medium_%d" % (i % 3 + 1), Vector3(cos(a) * 5.6 * AR, -0.6, sin(a) * 5.6 * AR), rng.randf() * 360.0, rng.randf_range(0.4, 0.6))
	recolor(kit("nature", "Rock_Medium_1"), func(_n: String, m: Material): return tinted(m, Color(0.16, 0.1, 0.22), Color(0.12, 0.0, 0.2), 0.4))
	recolor(kit("nature", "Rock_Medium_2"), func(_n: String, m: Material): return tinted(m, Color(0.16, 0.1, 0.22), Color(0.12, 0.0, 0.2), 0.4))
	recolor(kit("nature", "Rock_Medium_3"), func(_n: String, m: Material): return tinted(m, Color(0.16, 0.1, 0.22), Color(0.12, 0.0, 0.2), 0.4))
	# ilhas flutuantes (nós próprios para animar)
	var rock_m := mat(Color(0.07, 0.04, 0.1), 1.0, 0.0, Color(0.1, 0.0, 0.2), 0.6)
	for i in 36:
		var sm := SphereMesh.new()
		var r := rng.randf_range(0.5, 3.0)
		sm.radius = r; sm.height = r * 1.4; sm.radial_segments = 7; sm.rings = 4
		var p := Vector3(rng.randf_range(-40, 40), rng.randf_range(-15, 20), rng.randf_range(-10, 60))
		if Vector2(p.x, p.z).length() < 9.0 * AR:
			p.x += 12.0 * AR * sign(p.x + 0.01)
		var m := prim(sm, rock_m, p, Vector3(rng.randf(), rng.randf(), rng.randf()), null, false)
		islands.append([m, rng.randf_range(0.05, 0.3), rng.randf() * 6.0, p.y])
	# coração
	var hm := SphereMesh.new(); hm.radius = 9.0; hm.height = 18.0; hm.radial_segments = 64; hm.rings = 32
	var heart_m := ShaderMaterial.new()
	heart_m.shader = preload("res://shaders/heart.gdshader")
	heart_m.set_shader_parameter("vein_col", Color(0.8, 0.15, 1.0))
	heart_m.set_shader_parameter("body_col", Color(0.05, 0.0, 0.08))
	heart_m.set_shader_parameter("use_skin", true)
	heart_m.set_shader_parameter("skin_tex", load("res://assets/textures/limbo_heart.png"))
	heart = prim(hm, heart_m, Vector3(0, 4, 34), Vector3.ZERO, null, false)
	red = omni(Vector3(0, 6, 14), Color(0.7, 0.25, 1.0), 5.0, 40.0, false, false, 1.5)
	omni(Vector3(0, 3, 0), Color(0.6, 0.4, 0.9), 0.8, 10.0, false, false, 0.2)
	# olho da Presença (escondido até a revelação)
	eye = Node3D.new()
	eye.position = Vector3(0, 5, 25.5)
	add_child(eye)
	var em := SphereMesh.new(); em.radius = 1.2; em.height = 2.4
	prim(em, mat(Color(1.0, 0.25, 0.8), 0.4, 0.0, Color(1.0, 0.15, 0.75), 5.0), Vector3.ZERO, Vector3.ZERO, eye, false)
	var sl := SphereMesh.new(); sl.radius = 1.0; sl.height = 2.0
	slit = prim(sl, mat(Color(0, 0, 0), 1.0), Vector3(0, 0, -0.85), Vector3.ZERO, eye, false)
	slit.scale = Vector3(0.16, 0.95, 0.4)
	var halo := OmniLight3D.new(); halo.light_color = Color(1.0, 0.2, 0.75); halo.light_energy = 4.0; halo.omni_range = 14.0
	eye.add_child(halo)
	eye.visible = false
	flush()
	points = {"heart": Vector3(0, 4, 34), "center": Vector3.ZERO}
	ambient_particles("ember", Vector3(0, -2, 10), Vector3(25, 0, 25), 20.0, {"r": 1.0, "color": Color(0.8, 0.4, 1.0)})

func update(delta: float) -> void:
	var beat := maxf(0.0, sin(anim_t * 2.6))
	red.light_energy = 5.0 + beat * 2.0
	for it in islands:
		var m: MeshInstance3D = it[0]
		m.position.y = it[3] + sin(anim_t * it[1] + it[2]) * 0.6
		m.rotation.y += delta * it[1] * 0.3
	if eye.visible:
		eye.scale.y = 1.0 + sin(anim_t * 0.7) * 0.05
		slit.scale.x = 0.12 + maxf(0.0, sin(anim_t * 0.5)) * 0.1
