extends LevelBase
## Vardun à noite — rua principal com casas modulares do Medieval Village MegaKit.

const V := "village"
var rng := RandomNumberGenerator.new()
var lanterns: Array = []

func build() -> void:
	level_name = "vardun"
	surface = "stone"
	rng.seed = 1234
	bounds = {"type": "box", "min": Vector2(-4.3, -28.0), "max": Vector2(4.3, 40.3)}
	spawn = {"pos": Vector3(0, 0, -25), "yaw": 0.0}
	setup_env({"top": Color(0.012, 0.02, 0.06), "horizon": Color(0.08, 0.11, 0.24), "ambient": Color(0.28, 0.33, 0.55), "ambient_energy": 0.55,
		"fog": Color(0.07, 0.06, 0.17), "fog_density": 0.012, "vol_density": 0.018, "vol_albedo": Color(0.52, 0.5, 0.88), "sun": 0.55, "sun_col": Color(0.55, 0.65, 1.0), "sun_rot": Vector3(-38, -150, 0),
		"moon_dir": Vector3(-0.3, 0.42, 0.85), "exposure": 1.05, "glow": 0.9,
		"cloud_col": Color(0.09, 0.09, 0.22), "cloud_lit": Color(0.55, 0.5, 0.9), "purple": 0.15, "toon_shadow": Color(0.5, 0.48, 0.8), "toon_key": 0.32})
	floor_collider()
	_lit_windows()
	# calçamento
	for x in [-4, -2, 0, 2, 4]:
		for zi in range(-31, 44, 2):
			put(kit(V, "Floor_UnevenBrick"), Vector3(x, 0.0, zi), 90.0 * rng.randi_range(0, 3))
	# calçadas de tijolo junto às casas
	for zi in range(-31, 44, 2):
		put(kit(V, "Floor_Brick"), Vector3(-6, 0.01, zi))
		put(kit(V, "Floor_Brick"), Vector3(6, 0.01, zi))
	# casas
	var z := -32.0
	var idx := 0
	while z < 40.0:
		var w := rng.randi_range(2, 3)
		var floors := rng.randi_range(2, 3)
		var zc := z + w
		var rurik := zc > 6.0 and zc < 15.0 and idx >= 0
		house(-4.7, zc, -1, w, 3 if rurik else floors, 3, rurik)
		z += w * 2.0
		idx += 1
	z = -31.0
	while z < 38.0:
		var w := rng.randi_range(2, 3)
		var floors := rng.randi_range(2, 3)
		house(4.7, z + w, 1, w, floors, 3, false)
		z += w * 2.0
	# taverna de Darius no fim da rua (fachada para -Z)
	darius_tavern(Vector3(0, 0, 41.2))
	# casas que fecham o início da rua
	for x in [-3.0, 1.0, 3.0]:
		putk(V, "Wall_UnevenBrick_Straight", Vector3(x, 0, -31.0), 0.0)
		putk(V, "Wall_Plaster_WoodGrid", Vector3(x, 3.12, -31.0), 0.0)
	putk(V, "Wall_UnevenBrick_Door_Round", Vector3(-1.0, 0, -31.0), 0.0)
	putk(V, "Door_1_Round", Vector3(-1.0, 0, -30.95), 0.0)
	putk(V, "Wall_Plaster_Window_Wide_Round", Vector3(-1.0, 3.12, -31.0), 0.0)
	putk(V, "Window_Wide_Round1", Vector3(-1.0, 3.12, -31.0), 0.0)
	put(kit(V, "Roof_RoundTiles_4x8"), Vector3(0, 6.24, -33.0), 90.0)
	box_collider(Vector3(0, 3, -31.5), Vector3(10, 6, 1))
	# tochas (luz quente com halo na neblina)
	var lz := [-22.0, -12.0, -3.0, 6.5, 16.0, 26.0, 35.0]
	for i in lz.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		torch(Vector3(side * 4.55, 2.55, lz[i]), side, i < 6)
	# bandeirolas
	bunting(Vector3(-4.6, 5.2, -15), Vector3(4.6, 5.0, -14), [Color(0.6, 0.1, 0.1), Color(0.8, 0.4, 0.1), Color(0.15, 0.3, 0.55)])
	bunting(Vector3(-4.6, 5.4, 1), Vector3(4.6, 5.3, 2), [Color(0.6, 0.1, 0.1), Color(0.85, 0.7, 0.25), Color(0.15, 0.4, 0.3)])
	bunting(Vector3(-4.6, 5.3, 18), Vector3(4.6, 5.5, 19), [Color(0.5, 0.15, 0.4), Color(0.8, 0.4, 0.1), Color(0.15, 0.3, 0.55)])
	# adereços
	putk(V, "Prop_Wagon", Vector3(3.2, 0, -18.5), 180.0)
	box_collider(Vector3(3.2, 0.8, -20.1), Vector3(2.0, 1.6, 4.0))
	for p in [Vector3(-3.6, 0, -20.0), Vector3(3.7, 0, 3.5), Vector3(-3.6, 0, 24.0)]:
		putk(V, "Prop_Crate", p, rng.randf_range(0, 90), 0.75)
		putk(V, "Prop_Crate", p + Vector3(0, 0.79, 0), rng.randf_range(0, 90), 0.62)
		cyl_collider(p, 0.5, 1.6)
	for p in [Vector3(-3.7, 0, -18.6), Vector3(3.8, 0, 4.9), Vector3(-3.8, 0, 22.6), Vector3(3.8, 0, 30.0), Vector3(3.75, 0, 31.1)]:
		putk("dungeon", "barrel_large", p, rng.randf_range(0, 360), 0.48)
		cyl_collider(p, 0.45, 1.0)
	market_stall(Vector3(3.0, 0, -9.5), -90.0, Color(0.55, 0.12, 0.1))
	market_stall(Vector3(-3.0, 0, -0.5), 90.0, Color(0.15, 0.32, 0.5))
	market_stall(Vector3(3.0, 0, 21.5), -90.0, Color(0.5, 0.42, 0.15))
	for p in [Vector3(-4.3, 0, 30.0), Vector3(4.3, 0, -26.0)]:
		putk(V, "Prop_WoodenFence_Single", p, 90.0)
	# memorial de Lili
	memorial(Vector3(3.5, 0, -7.0))
	# placa da Taverna de Rurik
	sign_board(Vector3(-4.35, 3.45, 10.0), "TAVERNA\nde RURIK")
	# fundo: torres distantes, árvores
	for i in 5:
		var tx := rng.randf_range(-25, 25)
		var tz := rng.randf_range(58, 75)
		tower(Vector3(tx, 0, tz), rng.randf_range(1.0, 1.6))
	for i in 18:
		var p := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(48, 70))
		putk("nature", "Pine_%d" % rng.randi_range(1, 5), p, rng.randf_range(0, 360), rng.randf_range(1.2, 1.8))
	for i in 10:
		var p := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-55, -40))
		putk("nature", "CommonTree_%d" % rng.randi_range(1, 5), p, rng.randf_range(0, 360), rng.randf_range(1.2, 1.7))
	flush()
	points = {"mira": Vector3(2.6, 0, -6.6), "rurik": Vector3(-3.4, 0, 10.2), "near": Vector3(-3.6, 0, 12.8), "darius": Vector3(0, 0, 39.3), "memorial": Vector3(3.5, 0, -7.0)}
	ambient_particles("mote", Vector3(0, 3, 5), Vector3(5, 3, 34), 4.0)

func _lit_windows() -> void:
	var lit_mat := StandardMaterial3D.new()
	lit_mat.albedo_color = Color(0.9, 0.55, 0.25)
	lit_mat.emission_enabled = true
	lit_mat.emission = Color(1.0, 0.55, 0.22)
	lit_mat.emission_energy_multiplier = 1.1
	for wn in ["Window_Wide_Round1", "Window_Wide_Flat1", "Window_Thin_Round1"]:
		override_material(kit(V, wn), func(mmi: MultiMeshInstance3D, src: MeshInstance3D):
			for si in src.mesh.get_surface_count():
				var m = src.mesh.surface_get_material(si)
				if m and (m.resource_name.to_lower().contains("glass") or m.resource_name.to_lower().contains("window")):
					mmi.material_override = null
					var mesh_copy: Mesh = src.mesh.duplicate()
					mesh_copy.surface_set_material(si, lit_mat)
					mmi.multimesh.mesh = mesh_copy)

## Casa modular. fx: x da fachada; side -1 = lado esquerdo (fachada olha +X)
func house(fx: float, zc: float, side: int, w: int, floors: int, depth: int, rurik: bool) -> void:
	var rot := 90.0 if side < 0 else -90.0
	var dx := -1.0 if side < 0 else 1.0       # direção para dentro da casa
	var depth_m := depth * 2.0
	for f in floors:
		var y := f * 3.12
		for i in w:
			var zz := zc + (i - (w - 1) * 0.5) * 2.0
			var piece := ""
			if f == 0:
				if i == w / 2 and (rng.randf() < 0.7 or rurik):
					piece = "Wall_UnevenBrick_Door_Round"
					putk(V, "Door_1_Round", Vector3(fx + 0.06 * -dx, y, zz), rot)
				else:
					piece = "Wall_UnevenBrick_Window_Wide_Round" if rng.randf() < 0.5 else "Wall_UnevenBrick_Straight"
					if piece.contains("Window"):
						putk(V, "Window_Wide_Round1", Vector3(fx, y, zz), rot)
			else:
				var r := rng.randf()
				if r < 0.5 or rurik:
					piece = "Wall_Plaster_Window_Wide_Round"
					putk(V, "Window_Wide_Round1", Vector3(fx, y, zz), rot)
					if rng.randf() < 0.35:
						putk(V, "WindowShutters_Wide_Round_Open", Vector3(fx, y, zz), rot)
				elif r < 0.75:
					piece = "Wall_Plaster_WoodGrid"
				else:
					piece = "Wall_Plaster_Straight"
			putk(V, piece, Vector3(fx, y, zz), rot)
		# paredes laterais
		for k in depth:
			var xx := fx + dx * (k * 2.0 + 1.0)
			var zl := zc - w
			var zr := zc + w
			var sp := "Wall_UnevenBrick_Straight" if f == 0 else "Wall_Plaster_Straight"
			putk(V, sp, Vector3(xx, y, zl), 180.0)
			putk(V, sp, Vector3(xx, y, zr), 0.0)
		# cantos
		putk(V, "Corner_Exterior_Wood" if f > 0 else "Corner_Exterior_Brick", Vector3(fx, y, zc - w), rot)
		putk(V, "Corner_Exterior_Wood" if f > 0 else "Corner_Exterior_Brick", Vector3(fx, y, zc + w), rot)
		if f > 0 and rng.randf() < 0.25 and not rurik:
			for i in w:
				putk(V, "Balcony_Simple_Straight", Vector3(fx, y, zc + (i - (w - 1) * 0.5) * 2.0), rot)
		if f > 0 and rng.randf() < 0.3:
			putk(V, "Prop_Vine%d" % [1, 2, 4, 5, 6][rng.randi_range(0, 4)], Vector3(fx - dx * 0.12, y + 3.0, zc + rng.randf_range(-w + 0.6, w - 0.6)), rot)
	# telhado
	var top := floors * 3.12
	var cx := fx + dx * depth_m * 0.5
	var ww := w * 2
	var rname := "Roof_RoundTiles_%dx%d" % [depth_m, clamp(ww, 4, 14)]
	if not ResourceLoader.exists(kit(V, rname)):
		rname = "Roof_RoundTiles_6x6"
	put(kit(V, rname), Vector3(cx, top, zc), 0.0)
	var gable := "Roof_Front_Brick%d" % depth_m
	if ResourceLoader.exists(kit(V, gable)):
		putk(V, gable, Vector3(cx, top, zc - w), 180.0)
		putk(V, gable, Vector3(cx, top, zc + w), 0.0)
	if rng.randf() < 0.6:
		putk(V, "Prop_Chimney", Vector3(cx + dx * 1.2, top + 1.0, zc + rng.randf_range(-w + 1, w - 1)), 0.0)
	box_collider(Vector3(cx, 3.0, zc), Vector3(depth_m, 6.0, ww))
	if rurik:
		var l := omni(Vector3(fx + 0.8 * -dx, 1.6, zc), Color(1.0, 0.62, 0.3), 2.2, 7.0, false, true, 1.2)

func darius_tavern(c: Vector3) -> void:
	for i in 5:
		var x := c.x + (i - 2) * 2.0
		putk(V, "Wall_UnevenBrick_Door_Round" if i == 2 else "Wall_UnevenBrick_Straight", Vector3(x, 0, c.z), 180.0)
		putk(V, "Wall_UnevenBrick_Window_Wide_Round" if i % 2 == 1 else "Wall_UnevenBrick_Straight", Vector3(x, 3.12, c.z), 180.0)
	putk(V, "Door_1_Round", Vector3(c.x, 0, c.z - 0.06), 180.0)
	put(kit(V, "Roof_RoundTiles_6x10"), Vector3(c.x, 6.24, c.z + 3.0), 90.0)
	box_collider(Vector3(c.x, 3, c.z + 3.0), Vector3(10, 6, 6))
	var l := omni(Vector3(c.x, 2.4, c.z - 1.2), Color(1.0, 0.3, 0.15), 3.0, 7.0, false, true, 2.0)
	torch(Vector3(c.x - 1.6, 2.5, c.z - 0.25), 0.0, false, 180.0)
	torch(Vector3(c.x + 1.6, 2.5, c.z - 0.25), 0.0, false, 180.0)

func torch(p: Vector3, side: float, real_light: bool, rot := -999.0) -> void:
	var r := rot if rot > -900.0 else (90.0 if side < 0 else -90.0)
	putk("dungeon", "torch_mounted", p, r, 0.55)
	var flame := p + Vector3(-side * 0.2, 0.32, 0) if rot <= -900.0 else p + Vector3(0, 0.32, -0.2)
	var fl := omni(flame, Color(1.0, 0.6, 0.28), 2.6 if real_light else 1.4, 9.0 if real_light else 5.0, false, true, 1.6)
	lanterns.append(flame)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for f in lanterns:
		if randf() < delta * 14.0:
			Game.fx.burst("fire", f, {"n": 1, "r": 0.03, "size": 0.45})

func bunting(a: Vector3, b: Vector3, cols: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 22
	var pts := []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector3(0, -sin(t * PI) * 0.9, 0))
	var rope := MeshInstance3D.new()
	var rst := SurfaceTool.new()
	rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	Geo.tube(rst, PackedVector3Array(pts), Geo.taper(pts.size(), 0.012, 0.012), 4, 1.0)
	rope.mesh = rst.commit()
	rope.material_override = CharFactory.flat_mat(Color(0.12, 0.1, 0.08))
	add_child(rope)
	for c in cols.size():
		var mst := SurfaceTool.new()
		mst.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1, n):
			if i % cols.size() != c:
				continue
			var p: Vector3 = pts[i]
			var side := (b - a).normalized() * 0.2
			mst.add_vertex(p - side); mst.add_vertex(p + side); mst.add_vertex(p + Vector3(0, -0.45, 0))
		mst.generate_normals()
		var m := MeshInstance3D.new()
		m.mesh = mst.commit()
		m.material_override = CharFactory.flat_mat(cols[c])
		add_child(m)

func market_stall(p: Vector3, rot: float, col: Color) -> void:
	putk("dungeon", "table_medium", p, rot, 0.75)
	for k in 4:
		var o := Vector3(randf_range(-0.6, 0.6), 0.75, randf_range(-0.5, 0.5))
		putk("dungeon", ["plate_food_A", "plate_food_B", "box_small", "bottle_A_brown"][k], p + o, randf() * 360.0, 0.55)
	var aw := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(2.2, 0.05, 1.8)
	aw.mesh = bm
	aw.material_override = CharFactory.flat_mat(col)
	add_child(aw)
	aw.position = p + Vector3(0, 2.25, 0)
	aw.rotation = Vector3(0.0, deg_to_rad(rot), 0.22)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.04; cm.bottom_radius = 0.04; cm.height = 2.3
			post.mesh = cm
			post.material_override = CharFactory.flat_mat(Color(0.3, 0.2, 0.12))
			add_child(post)
			post.position = p + Basis(Vector3.UP, deg_to_rad(rot)) * Vector3(sx * 0.95, 1.15, sz * 0.8)
	box_collider(p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6), rot)

func memorial(p: Vector3) -> void:
	for i in 9:
		var o := Vector3(randf_range(-0.4, 0.3), 0, randf_range(-0.8, 0.8))
		putk("dungeon", "candle_lit" if i % 3 else "candle_thin_lit", p + o, randf() * 360.0, randf_range(0.35, 0.5))
	for i in 6:
		putk("nature", "Flower_4_Single" if i % 2 else "Flower_3_Single", p + Vector3(randf_range(-0.3, 0.2), 0, randf_range(-0.7, 0.7)), randf() * 360.0, 0.25)
	omni(p + Vector3(-0.2, 0.6, 0), Color(1.0, 0.62, 0.3), 1.6, 4.0, false, true, 0.8)

func sign_board(p: Vector3, text: String) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.85, 1.7)
	b.mesh = bm
	b.material_override = CharFactory.flat_mat(Color(0.3, 0.18, 0.1))
	add_child(b)
	b.position = p
	b.rotation.x = 0.06
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Cinzel.ttf")
	l.font_size = 64
	l.pixel_size = 0.0045
	l.modulate = Color(0.88, 0.74, 0.48)
	l.outline_size = 0
	l.position = p + Vector3(0.05, 0, 0)
	l.rotation.y = PI / 2.0
	add_child(l)

func tower(p: Vector3, s: float) -> void:
	for f in 4:
		for k in 4:
			var a := k * 90.0
			var off := Basis(Vector3.UP, deg_to_rad(a)) * Vector3(0, 0, 2.0)
			put(kit(V, "Wall_UnevenBrick_Straight" if f < 2 else "Wall_Plaster_Straight"), p + off * s + Vector3(0, f * 3.12 * s, 0), a, Vector3.ONE * s)
	put(kit(V, "Roof_Tower_RoundTiles"), p + Vector3(0, 4 * 3.12 * s, 0), 0.0, Vector3.ONE * s)
