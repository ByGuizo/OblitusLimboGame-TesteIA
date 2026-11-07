class_name Elemental
extends Boss
## A Criatura Mutável do Vale: essências de água, vento e fogo, cada uma com um núcleo.

const ELEM := preload("res://shaders/elemental.gdshader")

var form := "water"
var light: OmniLight3D
var core: MeshInstance3D
var core_mat: StandardMaterial3D
var mat: ShaderMaterial

func setup_elemental(o := {}) -> void:
	setup_boss("elemental", {"hp": o.get("hp", 1700.0), "dmg": 16.0, "speed": 2.6, "poise": 160.0, "radius": 1.15, "title": "A Essência Mutável", "pos": o.get("pos", Vector3.ZERO), "yaw": o.get("yaw", 0.0), "bleeds": false, "name": "Criatura do Vale"})
	pref_dist = 3.2
	ally_aggro = true
	height = 4.1
	mat = ShaderMaterial.new()
	mat.shader = ELEM
	for mi in rig.skel.get_children():
		if mi is MeshInstance3D:
			for si in mi.mesh.get_surface_count():
				mi.set_surface_override_material(si, mat)
	rig.mats = [mat]
	light = OmniLight3D.new()
	light.omni_range = 12.0
	light.light_energy = 2.4
	add_child(light)
	light.position = Vector3(0, 2.6, 1.6)
	core = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.11; sm.height = 0.22
	core.mesh = sm
	core_mat = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.emission_enabled = true
	core.material_override = core_mat
	var s3 := rig.skel.get_bone_global_rest(rig.skel.find_bone("spine_03")).origin
	rig.attach_model(core, "spine_03", Transform3D(Basis(), s3 + Vector3(0, 0, 0.12)))
	set_form("water")
	attacks = [
		{"w": 3.0, "max": 4.5, "cd": 2.5, "fn": whip, "phase": [1, 3]},
		{"w": 2.0, "min": 3.0, "cd": 5.0, "fn": wave, "phase": [1]},
		{"w": 2.0, "cd": 6.0, "fn": orbs, "phase": [1]},
		{"w": 3.0, "cd": 7.0, "fn": tornado, "phase": [2]},
		{"w": 3.0, "min": 3.0, "cd": 4.0, "fn": gust, "phase": [2]},
		{"w": 2.0, "max": 7.0, "cd": 6.0, "fn": cyclone, "phase": [2]},
		{"w": 3.0, "cd": 5.0, "fn": meteors, "phase": [3]},
		{"w": 2.0, "cd": 4.0, "fn": fireballs, "phase": [3]},
		{"w": 2.0, "max": 8.0, "cd": 8.0, "fn": flame_ring, "phase": [3]},
	]

func set_form(f: String) -> void:
	form = f
	var idx: int = {"water": 0, "wind": 1, "fire": 2}[f]
	mat.set_shader_parameter("form", idx)
	match f:
		"water":
			light.light_color = Color(0.38, 0.75, 1.0)
			core_mat.albedo_color = Color(0.6, 0.95, 1.0); core_mat.emission = Color(0.6, 0.95, 1.0); core_mat.emission_energy_multiplier = 2.2
			flying = false
		"wind":
			light.light_color = Color(0.75, 0.88, 1.0)
			core_mat.albedo_color = Color(1, 1, 1); core_mat.emission = Color(1, 1, 1); core_mat.emission_energy_multiplier = 2.2
			flying = true; fly_height = 0.9
		"fire":
			light.light_color = Color(1, 0.44, 0.12)
			core_mat.albedo_color = Color(1, 0.82, 0.38); core_mat.emission = Color(1, 0.7, 0.2); core_mat.emission_energy_multiplier = 6.0
			flying = false

func check_phase() -> void:
	var f := hp / max_hp
	if phase == 1 and f < 0.67:
		transform_to(2, "wind")
	elif phase == 2 and f < 0.34:
		transform_to(3, "fire")

func transform_to(ph: int, f: String) -> void:
	phase = ph
	clear_pending()
	busy = true
	busy_unstoppable = true
	ai = "attack"
	invulnerable = true
	rig.play("Idle_Shield_Break", {"speed": 0.6})
	Audio.sfx("roar", 0.8)
	Game.cam.shake(0.7)
	Game.fx.burst("water" if form == "water" else "wind", chest_pos(), {"n": 50, "r": 3.0})
	Game.after(0.7, func():
		set_form(f)
		Game.fx.sphere(chest_pos(), {"color": Color(1, 1, 1) if f == "wind" else Color(1, 0.5, 0.2), "r1": 5.0, "life": 0.6})
		Game.fx.flash(chest_pos(), Color(0.75, 0.88, 1.0) if f == "wind" else Color(1, 0.44, 0.12), 20.0, 0.6, 20.0)
		Audio.sfx("wind" if f == "wind" else "fire")
		Audio.sfx("explosion", 0.5)
		Game.emit_ev("bossPhase", {"boss": self, "phase": ph, "form": f}))
	Game.after(2.0, func():
		invulnerable = false
		busy_unstoppable = false
		done(0.0))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive:
		return
	light.light_energy = 4.0 + sin(Game.time * 6.0)
	core.scale = Vector3.ONE * (1.0 + sin(Game.time * 8.0) * 0.12)
	if form == "wind":
		fly_height = 0.9 + sin(Game.time * 2.0) * 0.2
		if randf() < 0.7: Game.fx.burst("wind", global_position, {"n": 1, "r": 1.6, "h": 4.0})
	elif form == "fire":
		if randf() < 0.8: Game.fx.burst("fire", global_position + Vector3(randf_range(-1, 1), randf_range(1, 4), randf_range(-1, 1)), {"n": 1, "size": 1.3})
	else:
		if randf() < 0.3: Game.fx.burst("water", global_position + Vector3(randf_range(-0.8, 0.8), randf_range(1, 3.5), randf_range(-0.8, 0.8)), {"n": 1})

func whip(t, _d) -> void:
	snap_face(t.global_position)
	var p := global_position
	var y := yaw
	var fire := form == "fire"
	queue_area({"shape": "cone", "pos": p, "yaw": y, "radius": 5.0, "angle": 2.4, "delay": 0.6, "dmg": dmg, "knock": 9.0,
		"on_trigger": func(_s): Game.fx.burst("fire" if fire else "water", p + Game.fwd(y) * 3.0 + Vector3(0, 1, 0), {"n": 25, "r": 1.5})})
	rig.play("Sword_Regular_B", {"speed": 0.5, "events": {0.22: "hit"}, "on_event": func(_e):
		Audio.sfx("fire" if fire else "splash")
		Game.fx.slash(chest_pos(), y, {"big": true, "scale": 1.8, "color": Color(1, 0.44, 0.12) if fire else Color(0.38, 0.75, 1.0), "intensity": 2.0, "flip": true})})
	done(1.1)

func wave(t, _d) -> void:
	snap_face(t.global_position)
	var p := global_position
	var y := yaw
	queue_area({"shape": "rect", "pos": p, "yaw": y, "width": 3.4, "length": 16.0, "delay": 1.0, "dmg": dmg * 1.15, "knock": 12.0,
		"on_trigger": func(_s):
			Audio.sfx("splash")
			for k in 16:
				Game.after(k * 0.025, func(): Game.fx.burst("water", p + Game.fwd(y) * k + Vector3(0, 0.3, 0), {"n": 8}))
			Game.cam.shake(0.4)})
	rig.play("OverhandThrow", {"speed": 0.9})
	done(1.5)

func orbs(_t, _d) -> void:
	rig.play("Spell_Simple_Shoot", {"speed": 0.6})
	Audio.sfx("magic")
	for k in 4:
		Game.after(k * 0.26, func():
			if not alive: return
			var s := chest_pos() + Vector3(randf_range(-1.5, 1.5), randf_range(0, 1), randf_range(-1.5, 1.5))
			var tg = pick_target()
			Game.spawn_projectile({"kind": "orb", "pos": s, "vel": (tg.chest_pos() - s).normalized() * 7.0, "team": "enemy", "dmg": 9.0, "radius": 0.5, "life": 5.0, "src": self, "color": Color(0.38, 0.78, 1.0), "scale": 1.8, "target": tg, "homing": 1.4,
				"trail": func(p, _dt): if randf() < 0.5: Game.fx.burst("water", p.pos, {"n": 1}),
				"on_expire": func(p): Game.fx.burst("water", p.pos, {"n": 12}); Audio.sfx("splash", 0.4)}))
	done(1.4)

func tornado(_t, _d) -> void:
	rig.play("Idle_Shield_Break", {"speed": 1.2})
	Audio.sfx("wind")
	for k in 3:
		var a := yaw + (k - 1) * 0.8
		Game.add_hazard({"kind": "wind", "pos": global_position + Game.fwd(a) * 3.0, "radius": 1.3, "dps": 14.0, "life": 6.0, "follow": pick_target(), "pull": 2.2, "src": self})
	done(1.2)

func gust(t, _d) -> void:
	var y := Game.yaw_to(global_position, t.global_position)
	var length: float = min(14.0, Game.dist2d(global_position, t.global_position) + 3.0)
	tel_only({"shape": "rect", "pos": global_position, "yaw": y, "width": 2.8, "length": length}, 0.8)
	rig.play("Shield_Dash", {"speed": 0.8})
	Audio.sfx("whoosh")
	busy_unstoppable = true
	var hit := []
	var tt := [0.0]
	Game.after(0.8, func():
		if not alive: return
		yaw = y
		busy_update = func(dt, _t2, _d2):
			tt[0] += dt
			move_vel = Game.fwd(y) * 18.0
			Game.fx.burst("wind", global_position, {"n": 3, "r": 1.5, "h": 3.0})
			for a in Game.allies_of_player():
				if not hit.has(a) and Game.dist2d(a.global_position, global_position) < radius + a.radius + 0.5:
					hit.append(a)
					Game.damage(self, a, dmg, {"heavy": true, "knock": 14.0})
			if tt[0] > length / 18.0:
				move_vel = Vector3.ZERO
				busy_update = Callable()
				busy_unstoppable = false
				done(0.6))

func cyclone(_t, _d) -> void:
	var p := global_position
	queue_area({"pos": p, "radius": 5.5, "delay": 1.1, "dmg": dmg, "knock": 15.0,
		"on_trigger": func(_s):
			Game.fx.ring(p, {"color": Color(0.88, 0.94, 1.0), "r1": 6.0, "life": 0.6})
			Game.fx.burst("wind", p, {"n": 60, "r": 5.0, "h": 3.0})
			Audio.sfx("wind"); Game.cam.shake(0.4)})
	rig.play("Idle_Shield_Break", {"speed": 1.0})
	done(1.6)

func meteors(_t, _d) -> void:
	rig.play("Spell_Simple_Shoot", {"speed": 0.5})
	Audio.sfx("fire")
	var targets := Game.allies_of_player()
	for k in 6:
		var tg = targets[k % targets.size()]
		var p: Vector3 = Game.player.global_position if k < 2 else tg.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		p.y = 0.0
		Game.after(k * 0.18, func():
			if not alive: return
			queue_area({"pos": p, "radius": 1.7, "delay": 1.1, "dmg": dmg * 1.1, "knock": 8.0,
				"on_trigger": func(_s):
					Game.fx.burst("fire", p, {"n": 30, "r": 0.8, "size": 1.5, "up": 2.0})
					Game.fx.burst("spark", p + Vector3(0, 0.3, 0), {"n": 15})
					Game.fx.flash(p + Vector3(0, 1, 0), Color(1, 0.38, 0.12), 8.0, 0.3)
					Audio.sfx("explosion", 0.5); Game.cam.shake(0.25)
					Game.add_hazard({"kind": "fire", "pos": p, "radius": 1.4, "dps": 12.0, "life": 4.0, "src": self})})
			Game.fx.meteor(p, 1.1))
	done(1.8)

func fireballs(_t, _d) -> void:
	rig.play("Spell_Simple_Shoot", {"speed": 0.7})
	Audio.sfx("fire")
	for k in 5:
		Game.after(k * 0.15, func():
			if not alive: return
			var s := chest_pos() + Vector3(0, 1, 0)
			var tg = pick_target()
			var dir: Vector3 = (tg.chest_pos() - s).normalized().rotated(Vector3.UP, (k - 2) * 0.12)
			Game.spawn_projectile({"kind": "orb", "pos": s, "vel": dir * 15.0, "team": "enemy", "dmg": 10.0, "radius": 0.5, "life": 3.0, "src": self, "color": Color(1, 0.44, 0.12), "scale": 1.5,
				"trail": func(p, _dt): Game.fx.burst("fire", p.pos, {"n": 1, "r": 0.05, "size": 0.8}),
				"on_expire": func(p): Game.fx.burst("fire", p.pos, {"n": 12, "r": 0.3})}))
	done(1.2)

func flame_ring(_t, _d) -> void:
	var p := global_position
	queue_area({"pos": p, "radius": 7.5, "inner": 2.6, "delay": 1.3, "dmg": dmg * 1.2, "knock": 10.0, "color": Color(1, 0.25, 0.06),
		"on_trigger": func(_s):
			Game.fx.shockwave(p, Color(1, 0.38, 0.12), 8.0, {"glow": Color(1.0, 0.4, 0.1)})
			for k in 40:
				var a := k / 40.0 * TAU
				Game.fx.burst("fire", p + Vector3(cos(a) * 5.0, 0, sin(a) * 5.0), {"n": 2, "size": 1.4})
			Audio.sfx("fire"); Game.cam.shake(0.5)})
	rig.play("OverhandThrow", {"speed": 0.8})
	done(1.8)
