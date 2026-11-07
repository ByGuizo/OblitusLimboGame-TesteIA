extends Node
## Cena principal (porte do fluxo de main.js): carrega níveis, roda o roteiro por trechos com
## reinício na morte, pausa, menus, captura do mouse e presets de qualidade.

var world: Node3D
var fx: FX
var cam: CameraRig
var ui: UIRoot
var post: PostFX
var menus: Menus
var story: Story
var mode := "boot"          # boot | title | game | credits | versus | versus_end
var dead := false
var run_token := 0
var args := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	Engine.max_physics_steps_per_frame = 4   # evita a espiral de passos de física quando o quadro atrasa
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			args[a.substr(2)] = "1"
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	Game.world = world
	fx = FX.new()
	fx.name = "FX"
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fx)
	Game.fx = fx
	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	Game.cam = cam
	post = PostFX.new()
	add_child(post)
	Game.post = post
	ui = UIRoot.new()
	add_child(ui)
	Game.ui = ui
	menus = Menus.new()
	add_child(menus)
	menus.act.connect(_on_menu)
	story = Story.new()
	story.name = "Story"
	story.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(story)
	D.story = story
	Game.ev.connect(_on_ev)
	apply_options(true)
	get_viewport().focus_exited.connect(func(): pass)
	_boot()

func _boot() -> void:
	if args.has("checkkits"):
		# teste: carrega e instancia todos os kits (erros de parse aparecem aqui)
		for id in Kits.IDS:
			var path := "res://scripts/combat/kits/kit_%s.gd" % id
			if not ResourceLoader.exists(path):
				print("KIT ", id, ": (ainda não existe)")
				continue
			var sc = load(path)
			if sc == null or not sc.can_instantiate():
				print("KIT ", id, ": ERRO")
				continue
			var k = sc.new(null)
			print("KIT ", id, ": ok  ", k.stats().name, " | skills=", k.skills().size(), " | ult=", k.ult_info().name)
		get_tree().quit()
		return
	if args.has("auto"):
		var h: Node = load("res://scripts/test/harness.gd").new()
		h.name = "Harness"
		add_child(h)
	if args.has("versus"):
		# --versus=p1,cpu,arena,dificuldade (testes / atalho)
		var vp: PackedStringArray = String(args.versus).split(",")
		await get_tree().process_frame
		Versus.start({"p1": vp[0] if vp.size() > 0 else "kiana", "cpu": vp[1] if vp.size() > 1 else "viktor",
			"arena": vp[2] if vp.size() > 2 else "throne", "diff": vp[3] if vp.size() > 3 else "normal", "rounds": int(vp[4]) if vp.size() > 4 else 2})
		return
	if args.has("test"):
		# harness: --test=ch,seg
		var p: PackedStringArray = String(args.test).split(",")
		await get_tree().process_frame
		start_game(int(p[0]), int(p[1]) if p.size() > 1 else 0)
		return
	if args.has("vsmenu"):
		await to_title(true)
		menus.hide_all()
		menus.show_versus_select()
		return
	if args.has("skipintro"):
		await to_title(true)
		return
	ui.fade_rect.modulate.a = 0.0
	Audio.sfx("gong", 0.5)
	var title_ready := [false]
	var load_title := func():
		await story.title_scene(true)
		title_ready[0] = true
	load_title.call()
	await menus.play_splash()
	while not title_ready[0]:
		await get_tree().process_frame
	if mode != "boot":
		return
	mode = "title"
	menus.hide_all()
	menus.show_title()
	_update_mouse()

# ---------------------------------------------------------------------
#  Opções
# ---------------------------------------------------------------------
func apply_options(first := false) -> void:
	var o: Dictionary = Save.opts
	Audio.set_volume("Master", o.master)
	Audio.set_volume("Music", o.music * (0.4 if get_tree().paused else 1.0))
	Audio.set_volume("SFX", o.sfx)
	cam.sens = o.sens
	cam.apply_quality()
	cam.invert_y = o.get("invert_y", false)
	Game.difficulty = o.diff
	if Game.player and is_instance_valid(Game.player) and not Game.player.versus:
		Game.player.dmg_taken_mul = o.diff
	var vp := get_viewport()
	match String(o.quality):
		"low":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.7
			vp.fsr_sharpness = 0.4
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			vp.positional_shadow_atlas_size = 1024
		"high":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			vp.positional_shadow_atlas_size = 4096
		_:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
			vp.fsr_sharpness = 0.35
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			vp.positional_shadow_atlas_size = 2048
	if not args.has("windowed") and not args.has("test"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if o.get("fullscreen", true) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if o.get("vsync", true) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if o.get("vsync", true) else 240

# ---------------------------------------------------------------------
#  Mouse
# ---------------------------------------------------------------------
func _playing() -> bool:
	return (mode == "game" or mode == "versus") and not dead and not get_tree().paused

func _update_mouse() -> void:
	var want := Input.MOUSE_MODE_CAPTURED if _playing() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_update_mouse.call_deferred()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and _playing() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("pause") and not e.is_echo():
		if menus.any_panel_open():
			_back()
		elif (mode == "game" or mode == "versus") and not dead:
			pause(not get_tree().paused)
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------
#  Níveis
# ---------------------------------------------------------------------
func clear_world() -> void:
	for a in Game.actors.duplicate():
		if is_instance_valid(a):
			a.alive = false
	Game.clear_systems()
	fx.clear()
	for c in world.get_children():
		world.remove_child(c)
		c.queue_free()
	Game.actors.clear()
	Game.player = null
	Game.boss = null
	Game.level = null
	Game.objective = null
	Game.in_combat = false
	Game.attack_tokens = 0
	Game.slow_t = 0.0
	Game.hitstop = 0.0
	Engine.time_scale = 1.0

func load_level(name: String, o := {}) -> LevelBase:
	ui.loading(true, o.get("label", "CARREGANDO"))
	await get_tree().process_frame
	await get_tree().process_frame
	clear_world()
	var L: LevelBase = load("res://scripts/levels/%s.gd" % name).new()
	L.name = name.capitalize()
	world.add_child(L)
	L.build()
	L.bound_walls()
	Game.level = L
	if o.has("player"):
		var p := Player.new()
		var pid: String = o.player
		if pid == "kiana" and (args.has("storychar") or not args.has("test")):
			# modo de teste: a história pode ser jogada com outro personagem no lugar da Kiana
			pid = String(args.get("storychar", Save.opts.get("story_char", "kiana")))
			if not Kits.IDS.has(pid): pid = "kiana"
		p.setup_player(pid, {"pos": o.get("pos", L.spawn.pos), "yaw": o.get("yaw", L.spawn.yaw)})
		world.add_child(p)
		p.dmg_taken_mul = Game.difficulty
		Game.player = p
		ui.set_player(p)
	else:
		ui.set_player(null)
	cam.snap_to_player()
	ui.boss(null)
	ui.kill_count("")
	ui.prompt("")
	# deixa os shaders compilarem atrás da tela de carregamento
	for i in 4:
		await get_tree().process_frame
	ui.loading(false)
	return L

# ---------------------------------------------------------------------
#  Fluxo do roteiro
# ---------------------------------------------------------------------
func start_game(ch: int, seg: int) -> void:
	Audio.sfx("uiOk")
	menus.hide_all()
	D.abort()
	run_from(ch, seg)

func run_from(ch: int, seg: int) -> void:
	run_token += 1
	var tok := run_token
	mode = "game"
	dead = false
	get_tree().paused = false
	menus.hide_all()
	_update_mouse()
	var chapters: Array = story.chapters()
	while true:
		if ch >= chapters.size():
			await show_credits()
			return
		var chapter: Dictionary = chapters[ch]
		if seg >= chapter.segments.size():
			ch += 1
			seg = 0
			Save.unlocked = maxi(Save.unlocked, ch)
			Save.write()
			continue
		D.cur = {"ch": ch, "seg": seg}
		Save.ch = ch
		Save.seg = seg
		Save.write()
		Game.emit_ev("segment", D.cur)
		await story.run(chapter.segments[seg])
		if tok != run_token:
			return
		D.end_segment()
		seg += 1

func restart_segment() -> void:
	D.abort()
	menus.hide_all()
	dead = false
	get_tree().paused = false
	var c: Dictionary = D.cur
	await get_tree().process_frame
	run_from(c.ch, c.seg)

func _on_ev(n: String, _data) -> void:
	if n == "playerDead":
		if mode != "game" or Game.player == null or not is_instance_valid(Game.player) or Game.player.alive:
			return
		dead = true
		var q: Array = Story.DEATH_QUOTES
		menus.show_death(q[randi() % q.size()])
		_update_mouse()
		Audio.music("limbo", 2.0)

func pause(on: bool) -> void:
	if (mode != "game" and mode != "versus") or dead:
		return
	get_tree().paused = on
	if on:
		menus.set_pause_versus(mode == "versus")
		menus.show_screen("pause")
		Audio.set_volume("Music", Save.opts.music * 0.4)
	else:
		menus.hide_all()
		Audio.set_volume("Music", Save.opts.music)
	_update_mouse()

func _back() -> void:
	for n in ["chapters", "codex", "options", "versus"]:
		menus.screens[n].visible = false
	if menus.panel_return == "title":
		menus.show_title()
	else:
		menus.show_screen("pause")
	Audio.sfx("ui")

func _end_versus() -> void:
	if Game.versus and is_instance_valid(Game.versus):
		Game.versus.abort()
	Game.versus = null

func to_title(first := false) -> void:
	_end_versus()
	run_token += 1
	D.abort()
	mode = "title"
	dead = false
	get_tree().paused = false
	menus.hide_all()
	ui.show_hud(false)
	ui.cine(false)
	_update_mouse()
	await story.title_scene(first)
	ui.fade_rect.modulate.a = 0.0
	menus.show_title()

func show_credits() -> void:
	mode = "credits"
	_update_mouse()
	ui.show_hud(false)
	Audio.music("title", 2.0)
	await menus.play_credits()
	to_title()

func _on_menu(a: String, arg) -> void:
	match a:
		"new":
			start_game(0, 0)
		"continue":
			start_game(Save.ch, Save.seg)
		"chapter":
			start_game(int(arg), 0)
		"chapters":
			menus.panel_return = "title"
			menus.hide_all()
			menus.fill_chapters(story.chapters_meta())
			menus.show_screen("chapters")
		"codex":
			menus.panel_return = "title"
			menus.hide_all()
			menus.fill_codex(Story.CODEX)
			menus.show_screen("codex")
		"options":
			menus.panel_return = "pause" if mode == "game" else "title"
			menus.hide_all()
			menus.sync_options()
			menus.show_screen("options")
		"option":
			Save.write()
			apply_options()
			if arg == "sfx":
				Audio.sfx("hit")
		"credits":
			menus.hide_all()
			show_credits()
		"back":
			_back()
		"resume":
			pause(false)
		"restart", "retry":
			if mode == "versus" and Game.versus:
				menus.hide_all()
				get_tree().paused = false
				Versus.start(Game.versus.cfg)
			else:
				restart_segment()
		"versus":
			menus.panel_return = "title"
			menus.hide_all()
			menus.show_versus_select()
		"versus_go":
			Audio.sfx("uiOk")
			menus.hide_all()
			Versus.start(arg)
		"rematch":
			Audio.sfx("uiOk")
			menus.hide_all()
			Versus.start(arg)
		"versus_change":
			await to_title()
			menus.hide_all()
			menus.panel_return = "title"
			menus.show_versus_select()
		"quit":
			to_title()
		"exit":
			get_tree().quit()
