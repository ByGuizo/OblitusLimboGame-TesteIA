extends LevelBase
## Vale das Flores Sangrentas — árvores retorcidas, capim de pontas roxas, flores vermelhas,
## acampamento com fogueira e a árvore das runas.

const N := "nature"
var rng := RandomNumberGenerator.new()
var rune_band: MeshInstance3D
var rune_material: ShaderMaterial
var fire_light: OmniLight3D
var camp := Vector3.ZERO

func build() -> void:
	level_name = "valley"
	surface = "grass"
	rng.seed = 4242
	bounds = {"type": "circle", "r": 13.0 if LevelBase.arena else 24.0, "c": Vector2.ZERO}
	cam_extra = 6.0
	spawn = {"pos": Vector3(-2.5, 0, -3), "yaw": 0.6}
	setup_env({"top": Color(0.03, 0.01, 0.03), "horizon": Color(0.28, 0.08, 0.14), "bottom": Color(0.04, 0.01, 0.02),
		"ambient": Color(0.6, 0.48, 0.62), "ambient_energy": 0.95, "stars": 0.6, "clouds": 0.8, "moon_dir": Vector3(0.4, 0.35, 0.85),
		"fog": Color(0.22, 0.07, 0.12), "fog_density": 0.03, "vol_density": 0.03, "vol_albedo": Color(0.75, 0.35, 0.5), "vol_ambient": 0.4,
		"sun": 1.25, "sun_col": Color(0.85, 0.66, 0.85), "sun_rot": Vector3(-42, 155, 0), "exposure": 1.05, "glow": 0.9, "fog_sky": 0.7,
		"cloud_col": Color(0.2, 0.06, 0.16), "cloud_lit": Color(0.8, 0.45, 0.75), "purple": 0.2, "toon_shadow": Color(0.55, 0.4, 0.7), "toon_key": 0.5})
	floor_collider()
	ground(160.0, 0, {"col_a": Color(0.1, 0.06, 0.06), "col_b": Color(0.12, 0.13, 0.07), "col_c": Color(0.35, 0.05, 0.12), "scale": 0.12,
		"use_ground": true, "ground_tex": load("res://assets/textures/valley_ground.png"), "tex_scale": 0.22, "ground_tint": Color(0.8, 0.62, 0.72)})
	# materiais: casca escura, folhas quase negras com tom vinho
	for t in 5:
		recolor(kit(N, "TwistedTree_%d" % (t + 1)), func(n: String, m: Material):
			return tinted(m, Color(0.42, 0.36, 0.42) if n.begins_with("Bark") else Color(0.22, 0.1, 0.14)))
		recolor(kit(N, "DeadTree_%d" % (t + 1)), func(_n: String, m: Material): return tinted(m, Color(0.4, 0.34, 0.38)))
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://shaders/grass_wind.gdshader")
	grass.set_shader_parameter("base_col", Color(0.05, 0.06, 0.04))
	grass.set_shader_parameter("mid_col", Color(0.16, 0.2, 0.1))
	grass.set_shader_parameter("tip_col", Color(0.42, 0.2, 0.55))
	grass.set_shader_parameter("emission_tip", 0.04)
	var grass_short: ShaderMaterial = grass.duplicate()
	grass_short.set_shader_parameter("height", 1.05)
	override_material(kit(N, "Grass_Wispy_Tall"), func(mmi: MultiMeshInstance3D, _s: MeshInstance3D):
		mmi.material_override = grass
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	override_material(kit(N, "Grass_Wispy_Short"), func(mmi: MultiMeshInstance3D, _s: MeshInstance3D):
		mmi.material_override = grass_short
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for fl in ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single"]:
		recolor(kit(N, fl), func(n: String, m: Material):
			if n.begins_with("Flower"):
				return tinted(m, Color(0.62, 0.04, 0.07), Color(0.25, 0.0, 0.03), 0.25)
			return tinted(m, Color(0.35, 0.3, 0.3)))
	recolor(kit(N, "Bush_Common"), func(_n: String, m: Material): return tinted(m, Color(0.25, 0.12, 0.16)))
	for r in 3:
		recolor(kit(N, "Rock_Medium_%d" % (r + 1)), func(_n: String, m: Material): return tinted(m, Color(0.5, 0.45, 0.5)))
	for g in ["Grass_Wispy_Tall", "Grass_Wispy_Short"]:
		batch_opts(kit(N, g), 10.0, 38.0, false)
	for g in ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single"]:
		batch_opts(kit(N, g), 10.0, 34.0, false)
	batch_opts(kit(N, "Bush_Common"), 14.0, 55.0, false)
	# árvores retorcidas: anel interno (obstáculos) e floresta externa
	var avoid := [[Vector3(0, 0, 0), 5.0], [Vector3(5, 0, 9), 4.5], [Vector3(-2.5, 0, -3), 3.0]]
	var trees_in := scatter([kit(N, "TwistedTree_1"), kit(N, "TwistedTree_2"), kit(N, "TwistedTree_3"), kit(N, "TwistedTree_4"), kit(N, "TwistedTree_5"), kit(N, "DeadTree_1"), kit(N, "DeadTree_3")],
		16, 9.0, 20.0, 0.4, 0.6, rng, avoid)
	for p in trees_in:
		cyl_collider(p, 0.55, 4.0)
		avoid.append([p, 2.5])
	var far := []
	for tn in ["TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "TwistedTree_4", "TwistedTree_5", "DeadTree_2", "DeadTree_4"]:
		far.append(kit(N, tn) + "#far")
		batch_opts(kit(N, tn) + "#far", 24.0, 0.0, false)
	scatter(far, 34, 22.0, 46.0, 0.45, 0.75, rng)
	# árvore das runas
	put(kit(N, "TwistedTree_3"), Vector3(5, 0, 9), 40.0, Vector3.ONE * 0.75)
	cyl_collider(Vector3(5, 0, 9), 0.9, 4.0)
	rune_material = rune_mat(Color(0.25, 0.62, 1.0), Vector2(18, 2), 0.0, 3.0)
	rune_band = prim(cyl(0.72, 0.8, 1.2, 24), rune_material, Vector3(5, 1.4, 9), Vector3.ZERO, null, false)
	(rune_band.mesh as CylinderMesh).cap_top = false
	(rune_band.mesh as CylinderMesh).cap_bottom = false
	# vegetação rasteira
	var q: String = Save.opts.get("quality", "med")
	var mul := 0.45 if q == "low" else (0.8 if q == "med" else 1.3)
	scatter([kit(N, "Grass_Wispy_Tall")], int(900 * mul), 3.0, 34.0, 0.32, 0.6, rng, [[Vector3.ZERO, 3.2]])
	scatter([kit(N, "Grass_Wispy_Short")], int(900 * mul), 2.5, 34.0, 0.4, 0.75, rng, [[Vector3.ZERO, 3.0]])
	scatter([kit(N, "Flower_3_Group"), kit(N, "Flower_4_Group")], int(260 * mul), 1.5, 32.0, 0.22, 0.38, rng, [[Vector3.ZERO, 2.2]])
	scatter([kit(N, "Flower_3_Single"), kit(N, "Flower_4_Single")], int(400 * mul), 1.0, 30.0, 0.25, 0.4, rng, [[Vector3.ZERO, 1.6]])
	scatter([kit(N, "Bush_Common")], 26, 12.0, 34.0, 0.6, 1.0, rng, avoid)
	var rocks := scatter([kit(N, "Rock_Medium_1"), kit(N, "Rock_Medium_2"), kit(N, "Rock_Medium_3")], 10, 10.0, 22.0, 0.35, 0.6, rng, avoid)
	for p in rocks:
		cyl_collider(p, 0.7, 1.0)
	# acampamento
	camp_build()
	flush()
	points = {"tree": Vector3(4.2, 0, 7.6), "camp": camp}
	ambient_particles("petal", Vector3(0, 0, 0), Vector3(14, 0, 14), 6.0, {"r": 1.0})
	ambient_particles("mote", Vector3(0, 0.5, 0), Vector3(20, 1, 20), 6.0, {"color": Color(0.9, 0.35, 0.7)})

func camp_build() -> void:
	var stone := mat(Color(0.26, 0.24, 0.26), 0.95)
	for i in 9:
		var a := i * TAU / 9.0
		var pm := SphereMesh.new(); pm.radius = 0.2; pm.height = 0.3; pm.radial_segments = 6; pm.rings = 3
		prim(pm, stone, camp + Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), Vector3(rng.randf(), rng.randf(), 0))
	var logm := mat(Color(0.2, 0.12, 0.07), 0.9)
	var charm := mat(Color(0.05, 0.03, 0.02), 1.0, 0.0, Color(0.9, 0.25, 0.05), 1.5)
	for i in 4:
		prim(cyl(0.07, 0.07, 1.0, 6), logm if i % 2 else charm, camp + Vector3(0, 0.16, 0), Vector3(PI * 0.5, i * 0.8, 0.3))
	var cols := [Color(0.36, 0.24, 0.17), Color(0.22, 0.28, 0.36), Color(0.36, 0.16, 0.22), Color(0.22, 0.34, 0.22)]
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		prim(box(Vector3(0.8, 0.12, 1.8)), mat(cols[i], 0.95), Vector3(cos(a) * 2.6, 0.06, sin(a) * 2.6), Vector3(0, -a, 0))
		prim(cyl(0.16, 0.16, 0.8, 8), mat(cols[i] * 0.8, 0.95), Vector3(cos(a) * 2.6, 0.16, sin(a) * 2.6) + Vector3(cos(a), 0, sin(a)) * 0.0 + Basis(Vector3.UP, -a) * Vector3(0, 0, -0.75), Vector3(0, -a, PI * 0.5))
	# mochilas e o ukulele de Kiana encostado
	putk("dungeon", "trunk_small_A", camp + Vector3(-1.8, 0, 1.6), 30.0, 0.45)
	putk("dungeon", "box_small", camp + Vector3(1.9, 0, -1.4), 10.0, 0.4)
	fire_light = omni(camp + Vector3(0, 0.8, 0), Color(1.0, 0.58, 0.3), 4.5, 15.0, Save.opts.get("quality", "med") == "high", true, 1.5)
	cyl_collider(camp, 0.8, 1.0)

func update(delta: float) -> void:
	if Game.fx == null:
		return
	if randf() < delta * 22.0:
		Game.fx.burst("fire", camp, {"n": 1, "r": 0.22})
	if randf() < delta * 5.0:
		Game.fx.burst("smoke", camp + Vector3(0, 1.0, 0), {"n": 1, "r": 0.2, "alpha": 0.25})
	if randf() < delta * 3.0:
		Game.fx.burst("ember", camp, {"n": 1, "r": 0.3})

## Revela as runas da árvore (0..1).
func set_runes(v: float) -> void:
	rune_material.set_shader_parameter("reveal", v)
