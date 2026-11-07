extends LevelBase
## Taverna de Darius — salão de madeira escura com mezanino, balcão de bebidas, lustre de velas.

const V := "village"
const K := "dungeon"
const W := 11.0
const DD := 9.0
const H := 6.24
var rng := RandomNumberGenerator.new()
var chandelier: Node3D
var flames: Array = []

func build() -> void:
	level_name = "tavern"
	surface = "wood"
	rng.seed = 77
	bounds = {"type": "box", "min": Vector2(-W + 0.6, -DD + 0.6), "max": Vector2(W - 0.6, DD - 0.6)}
	ceiling = H
	cam_extra = 0.0
	spawn = {"pos": Vector3(0, 0, -6.5), "yaw": 0.0}
	setup_env({"bg_color": Color(0.02, 0.012, 0.008), "ambient": Color(0.42, 0.36, 0.34), "ambient_energy": 0.5,
		"fog": Color(0.1, 0.06, 0.035), "fog_density": 0.02, "vol_density": 0.035, "vol_albedo": Color(0.85, 0.66, 0.6), "vol_ambient": 0.15,
		"sun": 0.0, "exposure": 1.0, "glow": 0.9, "saturation": 0.95,
		"purple": 0.1, "toon_shadow": Color(0.55, 0.45, 0.62), "toon_key": 0.3, "toon_rim_col": Color(1.0, 0.82, 0.7)})
	sun.visible = false
	floor_collider()
	# piso
	for x in range(-10, 11, 2):
		for z in range(-8, 9, 2):
			put(kit(V, "Floor_WoodDark"), Vector3(x, 0.0, z), 90.0 * rng.randi_range(0, 1))
			# teto (piso virado)
			put(kit(V, "Floor_WoodDark"), Vector3(x, H, z), 0.0, Vector3.ONE, Basis(Vector3.RIGHT, PI))
	# paredes: térreo de tijolo, andar de cima de reboco
	for f in 2:
		var y := f * 3.12
		for x in range(-10, 11, 2):
			var back := "Wall_UnevenBrick_Straight" if f == 0 else "Wall_Plaster_WoodGrid"
			var front := back
			if f == 0 and x == 0:
				back = "Wall_UnevenBrick_Door_Round"
			if f == 1 and abs(x) % 4 == 2:
				front = "Wall_Plaster_Window_Wide_Round"
				putk(V, "Window_Wide_Round1", Vector3(x, y, DD), 180.0)
				putk(V, "WindowShutters_Wide_Round_Closed", Vector3(x, y, DD), 180.0)
			putk(V, back, Vector3(x, y, -DD), 0.0)
			putk(V, front, Vector3(x, y, DD), 180.0)
		for z in range(-8, 9, 2):
			var r := "Wall_UnevenBrick_Straight" if f == 0 else "Wall_Plaster_Straight"
			var l := r
			if f == 0 and z == -4:
				r = "Wall_UnevenBrick_Door_Round"
			if f == 0 and z == 2:
				l = "Wall_UnevenBrick_Door_Round"
			putk(V, r, Vector3(W, y, z), -90.0)
			putk(V, l, Vector3(-W, y, z), 90.0)
	# portas
	putk(V, "Door_1_Round", Vector3(0, 0, -DD + 0.06), 0.0)
	putk(V, "Door_1_Round", Vector3(W - 0.06, 0, -4), -90.0)
	putk(V, "Door_1_Round", Vector3(-W + 0.06, 0, 2), 90.0)
	# vigas do teto
	var beam_m := mat(Color(0.16, 0.1, 0.06), 0.9)
	for i in range(-3, 4):
		prim(box(Vector3(0.35, 0.4, DD * 2)), beam_m, Vector3(i * 3.2, H - 0.22, 0), Vector3.ZERO, null, false)
	prim(box(Vector3(W * 2, 0.35, 0.35)), beam_m, Vector3(0, H - 0.5, 0), Vector3.ZERO, null, false)
	# mezanino nos fundos (z+) e à direita (x+)
	var by := 3.12
	for x in range(-10, 11, 2):
		put(kit(V, "Floor_WoodDark"), Vector3(x, by, DD - 1.0), 0.0)
		put(kit(V, "Floor_WoodDark"), Vector3(x, by - 0.02, DD - 1.0), 0.0, Vector3.ONE, Basis(Vector3.RIGHT, PI))
		putk(V, "Balcony_Simple_Straight", Vector3(x, by, DD - 2.0 - 0.9), 180.0)
	for z in range(-8, 7, 2):
		put(kit(V, "Floor_WoodDark"), Vector3(W - 1.0, by, z), 0.0)
		put(kit(V, "Floor_WoodDark"), Vector3(W - 1.0, by - 0.02, z), 0.0, Vector3.ONE, Basis(Vector3.RIGHT, PI))
		putk(V, "Balcony_Simple_Straight", Vector3(W - 2.0 - 0.9, by, z), -90.0)
	var post_m := mat(Color(0.2, 0.12, 0.07), 0.85)
	for x in range(-9, 10, 3):
		prim(box(Vector3(0.24, by, 0.24)), post_m, Vector3(x, by * 0.5, DD - 2.0), Vector3.ZERO)
		box_collider(Vector3(x, 1.5, DD - 2.0), Vector3(0.3, 3, 0.3), 0.0, false)
	for z in range(-7, 7, 3):
		prim(box(Vector3(0.24, by, 0.24)), post_m, Vector3(W - 2.0, by * 0.5, z), Vector3.ZERO)
		box_collider(Vector3(W - 2.0, 1.5, z), Vector3(0.3, 3, 0.3), 0.0, false)
	prim(box(Vector3(W * 2, 0.28, 0.3)), beam_m, Vector3(0, by - 0.14, DD - 2.0), Vector3.ZERO)
	prim(box(Vector3(0.3, 0.28, DD * 2 - 2.0)), beam_m, Vector3(W - 2.0, by - 0.14, -1.0), Vector3.ZERO)
	# escada até o mezanino
	putk(V, "Stair_Interior_Rails", Vector3(-W + 1.0, 0, DD - 2.0), 0.0)
	box_collider(Vector3(-W + 1.0, 1.0, DD - 4.2), Vector3(1.8, 2.0, 4.4), 0.0, true)
	# balcão de bebidas e prateleiras
	bar(Vector3(-4.0, 0, -DD + 1.7))
	# mesas (centro livre para a luta)
	for t in [[-8.2, 4.0, false], [8.0, -5.6, false], [-8.4, -2.6, false], [5.6, 5.4, true], [-4.6, 5.8, false], [1.4, 6.4, false], [7.6, 1.8, false]]:
		table(Vector3(t[0], 0, t[1]), t[2])
	# banquetas tombadas
	for i in 6:
		var p := Vector3(rng.randf_range(-6, 6), 0.18, rng.randf_range(-4, 4))
		put(kit(K, "stool"), p, rng.randf() * 360.0, Vector3.ONE * 0.7, Basis(Vector3(1, 0, 0.3).normalized(), PI * 0.5))
	# barris, pipas, caixas
	for p in [Vector3(10.0, 0, 7.4), Vector3(8.9, 0, 7.7), Vector3(10.1, 0, 6.2), Vector3(-10.0, 0, -7.6), Vector3(10.0, 0, -7.7)]:
		putk(K, "barrel_large", p, rng.randf() * 360.0, 0.48)
		cyl_collider(p, 0.45, 1.0)
	putk(K, "keg_decorated", Vector3(-1.2, 0, -DD + 0.9), 0.0, 0.5)
	putk(K, "crates_stacked", Vector3(-9.6, 0, -5.8), 30.0, 0.6)
	cyl_collider(Vector3(-9.6, 0, -5.8), 0.7, 1.4)
	putk(K, "barrel_small_stack", Vector3(9.8, 0, 4.0), -90.0, 0.55)
	box_collider(Vector3(9.8, 0.5, 4.0), Vector3(0.6, 1.0, 1.1), 0.0)
	# estandarte e escudos
	putk(K, "banner_patternC_red", Vector3(0, 3.6, DD - 0.35), 180.0, 0.9)
	putk(K, "sword_shield_broken", Vector3(6.0, 3.9, -DD + 0.45), 0.0, 0.7)
	putk(K, "sword_shield", Vector3(-W + 0.45, 2.2, -4.0), 90.0, 0.7)
	# lustre
	chandelier_build(Vector3(0, H - 2.0, 0))
	# arandelas
	for s in [[Vector3(-W + 0.25, 2.4, -4.0), 90.0], [Vector3(W - 0.25, 2.4, 2.6), -90.0], [Vector3(-W + 0.25, 2.4, 5.5), 90.0], [Vector3(3.0, 2.4, -DD + 0.25), 0.0], [Vector3(-6.0, 2.4, DD - 0.25), 180.0]]:
		sconce(s[0], s[1])
	flush()
	points = {"darius": Vector3(0, 0, 4.5), "doorBack": Vector3(0, 0, -DD + 1.2), "doorRight": Vector3(W - 1.2, 0, -4.0), "doorLeft": Vector3(-W + 1.2, 0, 2.0),
		"stairs": Vector3(-W + 1.4, 0, 2.5), "balcony": Vector3(4, 0, DD - 2.0), "center": Vector3.ZERO}
	ambient_particles("mote", Vector3(0, 1.5, 0), Vector3(9, 1.5, 7), 5.0, {"color": Color(1.0, 0.72, 0.45)})
	map_shapes.append({"type": "rect", "c": Vector2(-4.0, -DD + 1.7), "s": Vector2(6.2, 1.1), "r": 0.0})

func bar(c: Vector3) -> void:
	var wood := mat(Color(0.32, 0.18, 0.1), 0.6)
	var top := mat(Color(0.18, 0.1, 0.05), 0.35)
	prim(box(Vector3(6.0, 1.1, 0.9)), wood, c + Vector3(0, 0.55, 0))
	prim(box(Vector3(6.3, 0.1, 1.15)), top, c + Vector3(0, 1.13, 0))
	for i in 7:
		prim(box(Vector3(0.08, 1.0, 0.04)), top, c + Vector3(-2.7 + i * 0.9, 0.52, -0.47))
	box_collider(c + Vector3(0, 0.6, 0), Vector3(6.2, 1.2, 1.1), 0.0, false)
	for dx in [-2.0, 0.0, 2.0]:
		putk(K, "shelves", Vector3(c.x + dx, 0.2, -DD + 0.32), 0.0)
	var bottles := ["bottle_A_brown", "bottle_A_green", "bottle_B_brown", "bottle_B_green", "bottle_C_brown", "bottle_A_labeled_green", "bottle_C_green"]
	for s in 3:
		for k in 12:
			var x := c.x - 2.8 + k * 0.48 + rng.randf_range(-0.08, 0.08)
			putk(K, bottles[rng.randi() % bottles.size()], Vector3(x, 1.0 + s * 0.62, -DD + 0.55), rng.randf() * 360.0, 0.42)
	for k in 5:
		putk(K, ["bottle_A_brown", "plate_small", "bottle_B_green", "candle_lit", "plate_stack"][k], c + Vector3(-2.4 + k * 1.1, 1.18, 0.1), rng.randf() * 360.0, 0.45)
	flames.append(c + Vector3(-2.4 + 3 * 1.1, 1.5, 0.1))

func table(p: Vector3, toppled: bool) -> void:
	if toppled:
		put(kit(K, "table_medium"), p + Vector3(0, 0.75, 0), rng.randf() * 360.0, Vector3.ONE * 0.72, Basis(Vector3.RIGHT, PI * 0.5))
		cyl_collider(p, 0.7, 1.4)
		putk(K, "chair", p + Vector3(1.3, 0, 0.4), rng.randf() * 360.0, 0.75)
		return
	putk(K, "table_medium", p, rng.randf_range(-10, 10), 0.72)
	cyl_collider(p, 0.85, 1.0)
	for k in 3:
		var a := k * 2.1 + rng.randf()
		var cp := p + Vector3(cos(a), 0, sin(a)) * 1.25
		putk(K, "chair" if k < 2 else "stool", cp, rad_to_deg(atan2(p.x - cp.x, p.z - cp.z)), 0.75)
	putk(K, ["plate_food_A", "plate_food_B", "bottle_A_green"][rng.randi() % 3], p + Vector3(-0.3, 0.73, -0.2), rng.randf() * 360.0, 0.5)
	putk(K, "candle_lit", p + Vector3(0.25, 0.73, 0.15), 0.0, 0.55)
	flames.append(p + Vector3(0.25, 1.12, 0.15))
	if rng.randf() < 0.5:
		putk(K, "coin_stack_small", p + Vector3(0.1, 0.73, -0.35), rng.randf() * 360.0, 0.5)

func chandelier_build(p: Vector3) -> void:
	chandelier = Node3D.new()
	chandelier.position = p
	add_child(chandelier)
	var iron := mat(Color(0.06, 0.06, 0.06), 0.5, 0.7)
	var t1 := TorusMesh.new(); t1.inner_radius = 1.34; t1.outer_radius = 1.46; t1.rings = 32; t1.ring_segments = 6
	prim(t1, iron, Vector3.ZERO, Vector3.ZERO, chandelier)
	var t2 := TorusMesh.new(); t2.inner_radius = 0.65; t2.outer_radius = 0.75; t2.rings = 24; t2.ring_segments = 6
	prim(t2, iron, Vector3(0, 0.3, 0), Vector3.ZERO, chandelier)
	for i in 4:
		var a := i * PI * 0.5
		var ch := prim(cyl(0.015, 0.015, 2.4, 4), iron, Vector3(cos(a) * 0.7, 1.2, sin(a) * 0.7), Vector3.ZERO, chandelier)
		ch.rotation = Vector3(-sin(a) * 0.3, 0, cos(a) * 0.3)
	var wax := mat(Color(0.92, 0.86, 0.72), 0.6)
	var flame_m := mat(Color(1, 0.7, 0.3), 1.0, 0.0, Color(1.0, 0.6, 0.2), 6.0)
	for i in 15:
		var outer := i < 10
		var a := (i if outer else i - 10) * TAU / (10.0 if outer else 5.0)
		var r := 1.4 if outer else 0.7
		var cp := Vector3(cos(a) * r, 0.12 + (0.0 if outer else 0.3), sin(a) * r)
		prim(cyl(0.035, 0.04, 0.22, 6), wax, cp, Vector3.ZERO, chandelier, false)
		var fm := SphereMesh.new(); fm.radius = 0.035; fm.height = 0.12; fm.radial_segments = 6; fm.rings = 4
		prim(fm, flame_m, cp + Vector3(0, 0.16, 0), Vector3.ZERO, chandelier, false)
	var l := omni(p + Vector3(0, -0.4, 0), Color(1.0, 0.74, 0.5), 2.2, 16.0, false, true, 1.6)
	# a sombra vem de um spot apontado para baixo (1 face de sombra em vez de 6)
	var sp := SpotLight3D.new()
	sp.position = p + Vector3(0, -0.2, 0)
	sp.rotation_degrees = Vector3(-90, 0, 0)
	sp.spot_angle = 70.0
	sp.spot_range = 14.0
	sp.light_color = Color(1.0, 0.74, 0.5)
	sp.light_energy = 2.2
	sp.shadow_enabled = Save.opts.get("quality", "med") != "low"
	sp.shadow_bias = 0.05
	sp.light_volumetric_fog_energy = 1.2
	add_child(sp)
	flicker.append([sp, 2.2, 1.7])
	omni(Vector3(0, 2.2, 0), Color(0.75, 0.7, 0.8), 0.6, 14.0, false, false, 0.4)

func sconce(p: Vector3, rot: float) -> void:
	putk(K, "torch_mounted", p, rot, 0.55)
	var fwd := Basis(Vector3.UP, deg_to_rad(rot)) * Vector3(0, 0, 1)
	var fp := p + fwd * 0.2 + Vector3(0, 0.32, 0)
	omni(fp, Color(1.0, 0.66, 0.4), 1.8, 8.0, false, true, 1.4)
	flames.append(fp)

func update(delta: float) -> void:
	if chandelier:
		chandelier.rotation.y = sin(anim_t * 0.3) * 0.05
	if Game.fx == null:
		return
	for f in flames:
		if randf() < delta * 5.0:
			Game.fx.burst("fire", f, {"n": 1, "r": 0.01, "size": 0.18, "up": 0.3})
