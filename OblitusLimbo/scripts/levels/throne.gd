extends LevelBase
## Salão do Trono — Castelo de Hikari. Salão circular de mármore negro, pilares com globos
## arcanos, estandartes azuis, trono sobre o estrado e as correntes de Viktor.

const K := "dungeon"
const R := 13.0
var rng := RandomNumberGenerator.new()
var globes: Array = []
var chains: Array = []

func build() -> void:
	level_name = "throne"
	surface = "stone"
	rng.seed = 31
	bounds = {"type": "circle", "r": R - 0.5, "c": Vector2.ZERO}
	ceiling = 15.5
	cam_extra = 2.2
	spawn = {"pos": Vector3(0, 0, -10), "yaw": 0.0}
	setup_env({"bg_color": Color(0.01, 0.012, 0.03), "ambient": Color(0.36, 0.42, 0.66), "ambient_energy": 0.6,
		"fog": Color(0.05, 0.04, 0.12), "fog_density": 0.02, "vol_density": 0.025, "vol_albedo": Color(0.6, 0.55, 0.92), "vol_ambient": 0.25,
		"sun": 0.7, "sun_col": Color(0.6, 0.6, 1.0), "sun_rot": Vector3(-62, 200, 0), "exposure": 1.05, "glow": 1.0, "ssr": true,
		"purple": 0.15, "toon_shadow": Color(0.45, 0.45, 0.8), "toon_key": 0.35})
	floor_collider()
	ground(2.0 * (R + 7.0), 1, {"rune_radius": 4.5, "rune_col": Color(0.55, 0.45, 0.2)})
	# paredes circulares (peças de masmorra empilhadas)
	var wr := R + 6.0
	var nseg := 30
	for i in nseg:
		var a := i * TAU / nseg
		var p := Vector3(cos(a) * wr, 0, sin(a) * wr)
		var yaw := rad_to_deg(-a) - 90.0
		for f in 4:
			var piece := "wall"
			if f == 1 and i % 3 == 0:
				piece = "wall_archedwindow_gated"
			elif f == 0 and i % 5 == 2:
				piece = "wall_arched"
			put(kit(K, piece), p + Vector3(0, f * 4.0, 0), yaw, Vector3(1.02, 1.0, 1.0))
	# teto escuro com anel de vigas
	var ceil_m := mat(Color(0.03, 0.03, 0.05), 1.0)
	var cd := CylinderMesh.new(); cd.top_radius = wr + 1.0; cd.bottom_radius = wr + 1.0; cd.height = 0.4; cd.radial_segments = 48
	prim(cd, ceil_m, Vector3(0, 16.2, 0), Vector3.ZERO, null, false)
	var rim := TorusMesh.new(); rim.inner_radius = R + 0.4; rim.outer_radius = R + 1.4; rim.rings = 64; rim.ring_segments = 6
	prim(rim, mat(Color(0.08, 0.08, 0.11), 0.7), Vector3(0, 15.4, 0), Vector3.ZERO, null, false)
	# pilares com globos arcanos
	var globe_m := mat(Color(0.75, 0.88, 1.0), 0.3, 0.0, Color(0.7, 0.85, 1.0), 6.0)
	for i in 12:
		var a := i * TAU / 12.0 + PI / 12.0
		var p := Vector3(cos(a) * (R + 1.2), 0, sin(a) * (R + 1.2))
		for f in 3:
			put(kit(K, "pillar_decorated" if f == 0 else "pillar"), p + Vector3(0, f * 4.0, 0), rad_to_deg(-a) + 90.0, Vector3(0.75, 1.0, 0.75))
		put(kit(K, "column"), p + Vector3(0, 12.0, 0), 0.0, Vector3(1.6, 2.4, 1.6))
		cyl_collider(p, 0.75, 15.0, false)
		var gp := Vector3(p.x * 0.93, 4.2, p.z * 0.93)
		var sm := SphereMesh.new(); sm.radius = 0.3; sm.height = 0.6
		globes.append(prim(sm, globe_m, gp, Vector3.ZERO, null, false))
		prim(cyl(0.03, 0.05, 0.6, 6), mat(Color(0.5, 0.42, 0.22), 0.4, 0.8), gp + Vector3(0, -0.5, 0), Vector3.ZERO, null, false)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		omni(Vector3(cos(a) * R * 0.85, 4.5, sin(a) * R * 0.85), Color(0.66, 0.78, 1.0), 2.4, 16.0, i == 0, false, 1.0)
	# estrado e trono
	var marble := mat(Color(0.07, 0.07, 0.09), 0.15, 0.3)
	var gold := mat(Color(0.62, 0.5, 0.25), 0.35, 0.9)
	var dais := Vector3(0, 0, R + 1.5)
	for s in 3:
		prim(box(Vector3(8.0 - s * 1.6, 0.35, 4.0 - s * 0.8)), marble, dais + Vector3(0, 0.17 + s * 0.35, -s * 0.3))
		prim(box(Vector3(8.0 - s * 1.6 + 0.04, 0.04, 4.0 - s * 0.8 + 0.04)), gold, dais + Vector3(0, 0.34 + s * 0.35, -s * 0.3), Vector3.ZERO, null, false)
	box_collider(dais + Vector3(0, 0.5, 0), Vector3(8.0, 1.0, 4.0), 0.0, true)
	var th := dais + Vector3(0, 1.05, 0.6)
	var blue := mat(Color(0.07, 0.13, 0.26), 0.7)
	prim(box(Vector3(1.6, 0.6, 1.2)), blue, th + Vector3(0, 0.3, 0))
	prim(box(Vector3(1.8, 3.4, 0.3)), mat(Color(0.05, 0.06, 0.1), 0.5), th + Vector3(0, 1.7, 0.55))
	prim(box(Vector3(1.3, 2.6, 0.05)), blue, th + Vector3(0, 1.6, 0.38), Vector3.ZERO, null, false)
	for x in [-0.95, 0.95]:
		prim(box(Vector3(0.2, 0.9, 1.2)), mat(Color(0.05, 0.06, 0.1), 0.5), th + Vector3(x, 0.75, 0))
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.25; cone.height = 0.8; cone.radial_segments = 4
	prim(cone, gold, th + Vector3(-0.7, 3.8, 0.55))
	prim(cone, gold, th + Vector3(0.7, 3.8, 0.55))
	var cone2: CylinderMesh = cone.duplicate(); cone2.bottom_radius = 0.35; cone2.height = 1.1
	prim(cone2, gold, th + Vector3(0, 4.0, 0.55))
	box_collider(th + Vector3(0, 1.7, 0.4), Vector3(2.0, 3.4, 1.4), 0.0, false)
	# estátua da justiça desequilibrada
	var stone := mat(Color(0.22, 0.22, 0.26), 0.8)
	var st := dais + Vector3(0, 0, 3.6)
	prim(cyl(0.2, 0.25, 6.0, 8), stone, st + Vector3(0, 3.0, 0))
	var bm := prim(box(Vector3(4.0, 0.15, 0.15)), stone, st + Vector3(0, 6.0, 0), Vector3(0, 0, 0.35))
	prim(cyl(0.8, 0.5, 0.2, 12), stone, st + Vector3(1.8, 6.65, 0))
	prim(cyl(0.8, 0.5, 0.2, 12), stone, st + Vector3(-1.8, 5.35, 0))
	# estandartes azuis nas paredes
	for i in 8:
		var a := i * TAU / 8.0
		var p := Vector3(cos(a) * (wr - 0.6), 5.5, sin(a) * (wr - 0.6))
		put(kit(K, "banner_patternA_blue" if i % 2 == 0 else "banner_thin_blue"), p, rad_to_deg(-a) - 90.0, Vector3.ONE * 1.6)
	# candelabros no estrado
	for x in [-3.4, 3.4]:
		putk(K, "candle_triple", dais + Vector3(x, 0.35, -1.4), 0.0, 1.0)
		omni(dais + Vector3(x, 1.4, -1.6), Color(1.0, 0.7, 0.4), 1.2, 6.0, false, true, 0.8)
	# correntes de Viktor
	chains.append(chain(Vector3(-3.5, 4.5, R - 0.3), Vector3(-4.4, 2.2, R - 1.6)))
	chains.append(chain(Vector3(-5.4, 4.5, R - 0.3), Vector3(-4.6, 2.2, R - 1.6)))
	prim(box(Vector3(3.0, 0.4, 0.3)), stone, Vector3(-4.45, 4.6, R - 0.2))
	flush()
	points = {"throne": Vector3(0, 0, R - 1.5), "viktor": Vector3(-4.5, 0, R - 1.8), "calista": Vector3(2.5, 0, R - 3.5), "center": Vector3.ZERO}
	ambient_particles("mote", Vector3(0, 1, 0), Vector3(R, 2, R), 8.0, {"color": Color(0.62, 0.75, 1.0)})
	ambient_particles("smoke", Vector3(0, 0, 0), Vector3(R, 0, R), 2.5, {"r": 2.0, "color": Color(0.1, 0.12, 0.18), "alpha": 0.18, "size": 2.0})

func chain(a: Vector3, b: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _chain_mesh(a, b)
	mi.material_override = mat(Color(0.3, 0.3, 0.33), 0.4, 0.85)
	add_child(mi)
	return mi

func set_chain(i: int, a: Vector3, b: Vector3) -> void:
	if i < chains.size():
		chains[i].mesh = _chain_mesh(a, b)

func _chain_mesh(a: Vector3, b: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	var mid := a.lerp(b, 0.5) + Vector3(0, -0.25 - a.distance_to(b) * 0.08, 0)
	for i in 17:
		var t := i / 16.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	Geo.tube(st, PackedVector3Array(pts), Geo.taper(pts.size(), 0.035, 0.035), 5, 1.0)
	return st.commit()

func update(_delta: float) -> void:
	for i in globes.size():
		var g: MeshInstance3D = globes[i]
		g.scale = Vector3.ONE * (1.0 + sin(anim_t * 2.0 + i) * 0.06)
