extends Node3D
## Cena de teste visual. Argumentos: -- --mode=lineup | --mode=close --id=kiana --anim=Idle

var args := {}

func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var mode: String = args.get("mode", "lineup")
	if mode == "level":
		_level(); return
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.16, 0.17, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.58, 0.7); e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.1
	e.glow_enabled = true
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 35, 0); sun.shadow_enabled = true; sun.light_energy = 1.4; add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, -140, 0); fill.light_energy = 0.4; fill.light_color = Color(0.6, 0.7, 1.0); add_child(fill)
	var cam := Camera3D.new(); add_child(cam)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.35, 0.33, 0.32); floor.material_override = fm; add_child(floor)
	var anim: String = args.get("anim", "Idle")
	if mode == "lineup":
		var ids := ["kiana", "near", "calista", "amnon", "darin", "viktor", "krauser", "darius"]
		if args.has("ids"): ids = args.ids.split(",")
		for i in ids.size():
			var r := CharFactory.build(ids[i], {"seed": i})
			r.position = Vector3((i - (ids.size() - 1) / 2.0) * 1.05, 0, 0)
			add_child(r)
			r.play(anim, {"loop": true, "from": 0.3 * i, "blend": 0.0})
		cam.position = Vector3(0, 1.25, 6.6); cam.fov = 50
		cam.look_at(Vector3(0, 1.0, 0))
	elif mode == "close":
		var r := CharFactory.build(args.get("id", "kiana"), {"seed": 1})
		add_child(r)
		r.play(anim, {"loop": true, "blend": 0.0})
		var yaw := float(args.get("yaw", "0"))
		r.rotation.y = deg_to_rad(yaw)
		var h := r.height
		var dist := float(args.get("dist", "0.9"))
		var hy := float(args.get("y", str(h - 0.14)))
		cam.position = Vector3(0, hy, dist); cam.fov = 35
		cam.look_at(Vector3(0, hy - 0.02, 0))
	elif mode == "timeline":
		var names: PackedStringArray = args.get("anims", "Sword_Regular_A").split(",")
		for i in names.size():
			var r := CharFactory.build("near", {"seed": 1})
			r.position = Vector3((i - (names.size() - 1) / 2.0) * 1.5, 0, 0)
			r.rotation.y = deg_to_rad(70)
			add_child(r)
			r.play(names[i], {"loop": true, "blend": 0.0})
			var lb := Label3D.new(); lb.text = names[i]; lb.font_size = 36; lb.position = r.position + Vector3(0, 2.2, 0); lb.modulate = Color.WHITE; add_child(lb)
		var tl := Label3D.new(); tl.name = "TimeLabel"; tl.font_size = 64; tl.position = Vector3(0, 2.6, 0); tl.modulate = Color.YELLOW; add_child(tl)
		cam.position = Vector3(0, 1.3, 7.5); cam.fov = 55; cam.look_at(Vector3(0, 1.0, 0))
	elif mode == "full":
		var r := CharFactory.build(args.get("id", "kiana"), {"seed": 1})
		add_child(r)
		r.play(anim, {"loop": true, "blend": 0.0})
		r.rotation.y = deg_to_rad(float(args.get("yaw", "0")))
		cam.position = Vector3(0, 1.1, 3.2); cam.fov = 40
		cam.look_at(Vector3(0, 0.95, 0))

var _tt := 0.0
func _process(delta):
	_tt += delta
	var tl = get_node_or_null("TimeLabel")
	if tl: tl.text = "t=%.2f" % _tt

func _level():
	var fx := FX.new(); add_child(fx); Game.fx = fx; Game.world = self
	if args.has("q"): Save.opts.quality = args.q
	if args.has("skip"): LevelBase.skip = Array(args.skip.split(","))
	var L: LevelBase = load("res://scripts/levels/%s.gd" % args.get("id", "vardun")).new()
	add_child(L); Game.level = L
	L.build()
	if args.has("novol"): L.env.volumetric_fog_enabled = false
	if args.has("nossao"): L.env.ssao_enabled = false
	if args.has("noglow"): L.env.glow_enabled = false
	if args.has("nosky"): L.env.background_mode = Environment.BG_COLOR
	if args.has("noshadow"): L.sun.shadow_enabled = false
	if args.has("scale"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		get_viewport().scaling_3d_scale = float(args.scale)
	if args.has("perf"):
		var tt := [0.0, 0]
		var t0 := Time.get_ticks_msec()
		get_tree().process_frame.connect(func():
			tt[1] += 1
			if Time.get_ticks_msec() - t0 > 9000:
				printerr("PERF %s frames=%d fps=%.1f proc=%.2fms phys=%.2fms nav=%d" % [OS.get_cmdline_user_args(), tt[1], tt[1] / 9.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
				get_tree().quit())
	var cam := Camera3D.new(); add_child(cam); cam.current = true; cam.fov = 60
	if not args.has("nooutline"): Toon.make_outline_quad(cam)
	var cp: PackedStringArray = args.get("cam", "0,1.7,-26").split(",")
	var lk: PackedStringArray = args.get("look", "0,1.6,0").split(",")
	cam.position = Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
	cam.look_at(Vector3(float(lk[0]), float(lk[1]), float(lk[2])))
	if args.has("many"):
		for i in int(args.many):
			var r2 := CharFactory.build(["kiana", "near", "thug", "calista"][i % 4], {"seed": i})
			r2.position = Vector3((i % 6) * 1.2 - 3.0, 0, 4.0 + (i / 6) * 1.5)
			add_child(r2)
			if args.has("nocloth"): r2.set_cloth_active(false)
			if args.has("notree") and r2.tree: r2.tree.active = false
	if args.has("chars"):
		var ids: PackedStringArray = args.chars.split(",")
		for i in ids.size():
			var r := CharFactory.build(ids[i], {"seed": i})
			r.position = L.spawn.pos + Vector3((i - (ids.size() - 1) / 2.0) * 1.2, 0, 2.5)
			r.rotation.y = PI
			add_child(r)
