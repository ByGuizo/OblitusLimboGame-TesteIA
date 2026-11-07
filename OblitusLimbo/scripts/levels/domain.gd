extends LevelBase
## A Barreira do Infinito — clareira circular cercada de árvores, anel de runas, pilares e a
## rocha vermelha rachada.

const N := "nature"
const R := 16.0
var rng := RandomNumberGenerator.new()
var ring_mat: ShaderMaterial
var circle: MeshInstance3D
var rock_light: OmniLight3D

func build() -> void:
	level_name = "domain"
	surface = "grass"
	rng.seed = 909
	bounds = {"type": "circle", "r": R - 0.5, "c": Vector2.ZERO}
	cam_extra = 3.0
	spawn = {"pos": Vector3(0, 0, -10), "yaw": 0.0}
	setup_env({"sky_mode": 1, "veins": 0.6, "top": Color(0.03, 0.02, 0.07), "horizon": Color(0.16, 0.1, 0.26), "bottom": Color(0.03, 0.02, 0.04),
		"ambient": Color(0.55, 0.55, 0.8), "ambient_energy": 1.1, "fog": Color(0.12, 0.08, 0.2), "fog_density": 0.022,
		"vol_density": 0.022, "vol_albedo": Color(0.5, 0.45, 0.8), "vol_ambient": 0.35,
		"sun": 1.3, "sun_col": Color(0.72, 0.78, 1.0), "sun_rot": Vector3(-72, 210, 0), "exposure": 1.05, "glow": 1.0, "fog_sky": 0.5,
		"vein_col": Color(0.6, 0.35, 1.0), "vein_base": Color(0.05, 0.03, 0.1), "purple": 0.25, "toon_shadow": Color(0.48, 0.42, 0.8), "toon_key": 0.3})
	floor_collider()
	ground(140.0, 0, {"col_a": Color(0.1, 0.12, 0.07), "col_b": Color(0.16, 0.24, 0.1), "col_c": Color(0.12, 0.1, 0.2), "scale": 0.1,
		"use_ground": true, "ground_tex": load("res://assets/textures/domain_ground.png"), "tex_scale": 0.2, "ground_tint": Color(0.85, 0.82, 0.95)})
	for t in 5:
		recolor(kit(N, "TwistedTree_%d" % (t + 1)), func(n: String, m: Material):
			return tinted(m, Color(0.5, 0.45, 0.52) if n.begins_with("Bark") else Color(0.3, 0.26, 0.4)))
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://shaders/grass_wind.gdshader")
	grass.set_shader_parameter("base_col", Color(0.06, 0.09, 0.05))
	grass.set_shader_parameter("mid_col", Color(0.2, 0.3, 0.13))
	grass.set_shader_parameter("tip_col", Color(0.42, 0.5, 0.75))
	grass.set_shader_parameter("height", 1.05)
	override_material(kit(N, "Grass_Wispy_Short"), func(mmi: MultiMeshInstance3D, _s: MeshInstance3D):
		mmi.material_override = grass
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for fl in ["Flower_3_Group", "Flower_4_Group"]:
		recolor(kit(N, fl), func(n: String, m: Material):
			if n.begins_with("Flower"):
				return tinted(m, Color(0.62, 0.04, 0.07), Color(0.22, 0.0, 0.03), 0.25)
			return tinted(m, Color(0.4, 0.4, 0.4)))
	recolor(kit(N, "Rock_Medium_1"), func(_n: String, m: Material): return tinted(m, Color(0.85, 0.25, 0.2), Color(0.25, 0.02, 0.0), 0.4))
	batch_opts(kit(N, "Grass_Wispy_Short"), 10.0, 40.0, false)
	for g in ["Flower_3_Group", "Flower_4_Group"]:
		batch_opts(kit(N, g), 10.0, 36.0, false)
	for t in 5:
		batch_opts(kit(N, "TwistedTree_%d" % (t + 1)) + "#far", 24.0, 0.0, false)
	# muralha de árvores
	for i in 40:
		var a := i * TAU / 40.0 + rng.randf_range(0, 0.1)
		var r := R + rng.randf_range(3.0, 9.0)
		var tp := kit(N, "TwistedTree_%d" % rng.randi_range(1, 5)) + ("#far" if r > R + 5.0 else "")
		put(tp, Vector3(cos(a) * r, 0, sin(a) * r), rng.randf() * 360.0, Vector3.ONE * rng.randf_range(0.5, 0.75))
	var q: String = Save.opts.get("quality", "med")
	var mul := 0.45 if q == "low" else (0.8 if q == "med" else 1.3)
	scatter([kit(N, "Grass_Wispy_Short")], int(700 * mul), R - 1.0, R + 14.0, 0.4, 0.75, rng)
	scatter([kit(N, "Grass_Wispy_Short")], int(160 * mul), 2.0, R - 2.0, 0.25, 0.4, rng)
	scatter([kit(N, "Flower_3_Group"), kit(N, "Flower_4_Group")], int(220 * mul), R - 2.0, R + 12.0, 0.22, 0.38, rng)
	scatter([kit(N, "Flower_3_Group"), kit(N, "Flower_4_Group")], int(60 * mul), 2.0, R - 3.0, 0.18, 0.3, rng)
	# anel de runas no chão
	ring_mat = rune_mat(Color(0.25, 0.66, 1.0), Vector2(64, 1), 1.0, 3.5)
	prim(ring_mesh(R - 0.6, R + 0.6, 128, 1.0), ring_mat, Vector3(0, 0.03, 0), Vector3.ZERO, null, false)
	# rocha vermelha rachada além do anel
	var rp := Vector3(0, 0, R + 4.0)
	put(kit(N, "Rock_Medium_1"), rp + Vector3(0, -0.3, 0), 20.0, Vector3(2.0, 2.6, 1.8))
	cyl_collider(rp, 3.0, 4.0, false)
	circle = prim(ring_mesh(0.4, 4.5, 64, 1.0), rune_mat(Color(0.25, 0.66, 1.0), Vector2(16, 4), 1.0, 1.6), rp + Vector3(0, 0.04, -1.0), Vector3.ZERO, null, false)
	rock_light = omni(rp + Vector3(0, 2.0, -3.0), Color(0.3, 0.6, 1.0), 3.0, 14.0, false, false, 1.5)
	omni(Vector3(0, 14, 0), Color(0.55, 0.6, 1.0), 2.0, 40.0, false, false, 0.3)
	# pilares rúnicos
	for i in 6:
		var a := i * TAU / 6.0
		var p := Vector3(cos(a) * (R + 1.5), 0, sin(a) * (R + 1.5))
		put(kit("dungeon", "pillar"), p, rad_to_deg(-a), Vector3(0.55, 1.0, 0.55))
		prim(cyl(0.48, 0.48, 2.6, 4), rune_mat(Color(0.25, 0.66, 1.0), Vector2(4, 6), 1.0, 2.0), p + Vector3(0, 2.0, 0), Vector3(0, -a + PI * 0.25, 0), null, false)
	flush()
	points = {"boss": Vector3(0, 0, 7), "rock": Vector3(0, 0, R + 2.0), "center": Vector3.ZERO}
	ambient_particles("mote", Vector3(0, 0.5, 0), Vector3(R, 1, R), 10.0, {"color": Color(0.4, 0.62, 1.0)})
	ambient_particles("petal", Vector3(0, 1, 0), Vector3(R * 0.8, 0, R * 0.8), 5.0, {"r": 1.0})

func update(_delta: float) -> void:
	ring_mat.set_shader_parameter("intensity", 3.2 + sin(anim_t * 2.0) * 0.8)
	if circle:
		circle.rotation.y = anim_t * 0.2
	if rock_light:
		rock_light.light_energy = 3.0 + sin(anim_t * 3.0) * 0.8
