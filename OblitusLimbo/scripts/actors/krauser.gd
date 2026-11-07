class_name Krauser
extends Boss
## Lorde Krauser, o verdadeiro Quinto Presságio. Tentáculos do Abismo + Frio Absoluto.

var tentacles: Array = []
var tentacles_on := true
var armor := false
var armor_broken := 0.0
var armor_light: OmniLight3D
var aura: OmniLight3D
var dying := false

class Tentacle:
	var segs: Array[MeshInstance3D] = []
	var tip: MeshInstance3D
	var side := 1.0
	var up := 1.0
	var target = null
	var extend := 0.0
	var phase := 0.0
	var n := 16
	func _init(parent: Node, s: float, u: float) -> void:
		side = s; up = u; phase = randf() * 10.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.04, 0.07)
		mat.roughness = 0.35
		mat.emission_enabled = true
		mat.emission = Color(0.16, 0.04, 0.2)
		mat.rim_enabled = true
		mat.rim = 0.6
		for i in n:
			var r := 0.13 * (1.0 - float(i) / n) + 0.03
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 10; sm.rings = 6
			m.mesh = sm
			m.material_override = mat
			parent.add_child(m)
			segs.append(m)
		tip = MeshInstance3D.new()
		var ts := SphereMesh.new(); ts.radius = 0.05; ts.height = 0.1
		tip.mesh = ts
		var tm := StandardMaterial3D.new(); tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = Color(1, 0.16, 0.42); tm.emission_enabled = true; tm.emission = Color(1, 0.16, 0.42); tm.emission_energy_multiplier = 3.0
		tip.material_override = tm
		parent.add_child(tip)
	func update(t: float, base: Vector3, back: Vector3, right: Vector3) -> void:
		var idle_tip := base + back * 1.4 + right * side * 1.2 + Vector3(0, up * 0.8 + sin(t * 1.7 + phase) * 0.35, 0) + right * sin(t * 1.3 + phase) * 0.3
		var tip_pos: Vector3 = idle_tip.lerp(target, extend) if target != null else idle_tip
		var ctrl := base + back * 0.6 + Vector3(0, 1.4 + up * 0.4, 0) + right * side * 0.7
		if target != null:
			ctrl = ctrl.lerp(Vector3((base.x + target.x) * 0.5, max(base.y, target.y) + 2.2, (base.z + target.z) * 0.5), extend)
		for i in n:
			var u := float(i) / (n - 1)
			var p := base * (1.0 - u) * (1.0 - u) + ctrl * 2.0 * (1.0 - u) * u + tip_pos * u * u
			p.x += sin(t * 5.0 + i * 0.7 + phase) * 0.04 * u
			segs[i].global_position = p
		tip.global_position = segs[n - 1].global_position
	func set_visible(v: bool) -> void:
		for s in segs: s.visible = v
		tip.visible = v
	func free_all() -> void:
		for s in segs: if is_instance_valid(s): s.queue_free()
		if is_instance_valid(tip): tip.queue_free()

func setup_krauser(o := {}) -> void:
	setup_boss("krauser", {"hp": o.get("hp", 1900.0), "dmg": 15.0, "speed": 3.2, "poise": 150.0, "radius": 0.6, "title": "O Quinto Presságio", "pos": o.get("pos", Vector3.ZERO), "yaw": o.get("yaw", 0.0), "name": "Lorde Krauser"})
	pref_dist = 2.6
	cd_base = 1.3
	armor_light = OmniLight3D.new(); armor_light.light_color = Color(0.23, 0.48, 1.0); armor_light.light_energy = 0.0; armor_light.omni_range = 8.0
	add_child(armor_light); armor_light.position = Vector3(0, 1.3, 0)
	aura = OmniLight3D.new(); aura.light_color = Color(0.7, 0.45, 1.0); aura.light_energy = 3.5; aura.omni_range = 7.0
	add_child(aura); aura.position = Vector3(0, 1.8, 1.1)
	attacks = [
		{"w": 3.0, "max": 3.4, "cd": 2.4, "fn": claw_combo},
		{"w": 3.0, "cd": 4.0, "fn": tentacle_slam},
		{"w": 2.0, "max": 6.0, "cd": 7.0, "fn": tentacle_sweep},
		{"w": 2.0, "min": 2.0, "max": 12.0, "cd": 8.0, "fn": breath},
		{"w": 2.0, "cd": 9.0, "fn": blue_nova, "phase": [2, 3]},
		{"w": 1.0, "cd": 14.0, "fn": summon, "phase": [1, 2]},
	]
	corpse_time = 999.0

func _ready() -> void:
	tentacles = [Tentacle.new(Game.world, -1.0, 1.0), Tentacle.new(Game.world, 1.0, 1.0), Tentacle.new(Game.world, -1.0, -0.3), Tentacle.new(Game.world, 1.0, -0.3)]

func _exit_tree() -> void:
	super._exit_tree()
	for t in tentacles:
		t.free_all()

func set_armor(on: bool) -> void:
	armor = on
	resist = {"ice": 0.25} if on else {}
	armor_light.light_energy = 4.0 if on else 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var back := -Game.fwd(yaw)
	var right := Vector3(-cos(yaw), 0, sin(yaw))
	var base := chest_pos() + back * 0.25
	for tc in tentacles:
		tc.set_visible(tentacles_on and visible)
		if tentacles_on:
			tc.update(Game.time, base, back, right)
	dmg_taken_mul = 1.0 + min(0.5, resonance * 0.008)
	if resonance > 20 and randf() < 0.15:
		Game.fx.burst("magic", chest_pos(), {"n": 1, "color": Color(0.5, 0.95, 1.0), "color2": Color(1, 0.82, 0.44), "speed": 0.4, "size": 0.6})
	if armor_broken > 0.0:
		armor_broken -= delta
		if armor: set_armor(false)
		if armor_broken <= 0.0 and phase >= 3: set_armor(true)
	if armor and randf() < 0.9:
		Game.fx.burst("fire", global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 2.0), randf_range(-0.5, 0.5)), {"n": 1, "color": Color(0.82, 0.9, 1.0), "color2": Color(0.06, 0.2, 1.0), "size": 0.9, "r": 0.05})
	if phase >= 2 and randf() < 0.3:
		Game.fx.burst("shadow", global_position + Vector3(0, randf_range(0.2, 2.0), 0), {"n": 1, "r": 0.6})

func check_phase() -> void:
	if phase_lock:
		return
	if phase == 1 and hp <= max_hp * 0.6 + 1.0:
		phase_lock = true
		Game.emit_ev("krauserThreshold", 1)
	elif phase == 2 and hp <= max_hp * 0.12 + 1.0:
		phase_lock = true
		Game.emit_ev("krauserThreshold", 2)

func tentacle_strike(tc: Tentacle, p: Vector3, delay := 0.9, d := -1.0) -> void:
	queue_area({"pos": p, "radius": 1.5, "delay": delay, "dmg": dmg * 1.15 if d < 0.0 else d, "knock": 9.0,
		"on_trigger": func(_s):
			Game.fx.burst("dust", p, {"n": 12})
			Game.fx.burst("shadow", p + Vector3(0, 0.5, 0), {"n": 10, "r": 0.5})
			Game.cam.shake(0.3)
			Audio.sfx("hitHeavy", 0.6)})
	Game.after(max(0.0, delay - 0.2), func():
		if not alive: return
		Audio.sfx("tentacle")
		tc.target = p + Vector3(0, 0.2, 0)
		var tw := create_tween()
		tw.tween_property(tc, "extend", 1.0, 0.18)
		tw.tween_interval(0.17)
		tw.tween_property(tc, "extend", 0.0, 0.35)
		tw.tween_callback(func(): tc.target = null))

func claw_combo(_t, _d) -> void:
	glint()
	var n := [0]
	var count := 3 if phase >= 2 else 2
	Game.after(0.15, func(): _claw_step(n, count))
	done(1.9 if phase >= 2 else 1.3)

func _claw_step(n: Array, count: int) -> void:
	if not alive or ai == "stun":
		return
	snap_face(target.global_position)
	var y := yaw
	move_vel = Game.fwd(y) * 3.0
	rig.play("Sword_Regular_A" if n[0] % 2 == 0 else "Sword_Regular_B", {"speed": 0.85, "events": {0.18: "hit"}, "on_event": func(_e):
		Audio.sfx("swing")
		Game.fx.slash(global_position + Vector3(0, 1.4, 0), y, {"roll": -0.8 if n[0] % 2 else 0.8, "flip": n[0] % 2 == 1, "color": Color(0.42, 0.63, 1.0) if phase >= 2 else Color(0.75, 0.25, 1.0), "intensity": 2.0, "dark": true, "scale": 1.1})
		for a in Game.allies_of_player():
			if Game.dist2d(a.global_position, global_position) < 2.8 + a.radius and abs(Game.ang_diff(Game.yaw_to(global_position, a.global_position), y)) < 1.1:
				Game.damage(self, a, dmg, {"knock": 5.0})})
	n[0] += 1
	if n[0] < count:
		Game.after(0.52, func(): _claw_step(n, count))

func tentacle_slam(_t, _d) -> void:
	rig.play("Spell_Simple_Shoot", {"speed": 0.6})
	Audio.sfx("tentacle")
	var n := 4 if phase >= 2 else 3
	var targets := Game.allies_of_player()
	for k in n:
		var tg = Game.player if k == 0 else targets[k % targets.size()]
		var p: Vector3 = tg.global_position + (Vector3.ZERO if k == 0 else Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6)))
		p.y = 0.0
		Game.after(k * 0.26, func(): if alive: tentacle_strike(tentacles[k % 4], p))
	done(1.6)

func tentacle_sweep(_t, _d) -> void:
	var p := global_position
	queue_area({"pos": p, "radius": 6.0, "delay": 1.15, "dmg": dmg * 1.1, "knock": 14.0,
		"on_trigger": func(_s):
			Game.fx.shockwave(p, Color(0.63, 0.25, 1.0), 6.5, {"glow": Color(0.6, 0.2, 1.0)})
			Game.fx.burst("shadow", p + Vector3(0, 0.6, 0), {"n": 40, "r": 4.0})
			Game.cam.shake(0.5)
			Audio.sfx("tentacle"); Audio.sfx("swingHeavy")})
	rig.play("Idle_Shield_Break", {"speed": 1.0})
	var tt := [0.0]
	Game.fx.custom(1.6, func(t, _dt):
		for i in tentacles.size():
			var tc: Tentacle = tentacles[i]
			if t > 1.0 and t < 1.5:
				var a: float = yaw + i * PI / 2.0 + (t - 1.0) * 14.0
				tc.target = p + Vector3(cos(a) * 5.0, 0.5, sin(a) * 5.0)
				tc.extend = 1.0
			elif t >= 1.5:
				tc.target = null; tc.extend = 0.0)
	done(1.7)

func breath(t, _d) -> void:
	snap_face(t.global_position)
	var y := yaw
	var p := global_position
	var blue := phase >= 2
	pend.append(Game.fx.telegraph({"shape": "cone", "pos": p, "angle": 1.0, "radius": 9.0, "yaw": y}, 0.85, Color(0.16, 0.38, 1.0) if blue else Color(1, 0.25, 0.06)))
	rig.play("Idle_Shield_Break", {"speed": 1.3})
	Audio.sfx("roar", 0.5)
	Game.after(0.85, func():
		if not alive or ai == "stun": return
		Audio.sfx("fire"); Game.after(0.5, func(): Audio.sfx("fire")); Game.after(1.0, func(): Audio.sfx("fire"))
		var ticks := [0]
		Game.fx.custom(1.5, func(tt, _dt):
			var mouth := head_pos(-0.15) + Game.fwd(y) * 0.3
			Game.fx.breath_puff(mouth, y, blue)
			if tt > ticks[0] * 0.25:
				ticks[0] += 1
				for a in Game.allies_of_player():
					if Game.dist2d(a.global_position, p) < 9.0 and abs(Game.ang_diff(Game.yaw_to(p, a.global_position), y)) < 0.55:
						Game.damage(self, a, 6.0, {"knock": 2.0, "fx": false, "vol": 0.5, "element": "fire"}),
			func(): if blue: Game.add_hazard({"kind": "blueflame", "pos": p + Game.fwd(y) * 5.0, "radius": 2.0, "dps": 12.0, "life": 5.0, "src": self})))
	done(2.6)

func blue_nova(_t, _d) -> void:
	rig.play("Spell_Simple_Shoot", {"speed": 0.5})
	Audio.sfx("reveal", 0.6)
	if Game.ui: Game.ui.bark("krauser", "Armadura Arcana: Frio Absoluto!")
	for k in 6:
		var a := randf() * TAU
		var r := randf_range(2.0, 10.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if k == 0:
			p = Game.player.global_position; p.y = 0.0
		queue_area({"pos": p, "radius": 2.0, "delay": 1.2, "dmg": dmg, "knock": 6.0, "color": Color(0.16, 0.38, 1.0),
			"on_trigger": func(_s):
				Game.fx.burst("fire", p, {"n": 20, "color": Color(0.88, 0.94, 1.0), "color2": Color(0.06, 0.25, 1.0), "size": 1.4, "up": 2.0})
				Game.add_hazard({"kind": "blueflame", "pos": p, "radius": 1.8, "dps": 14.0, "life": 6.0, "src": self})})
	done(1.8)

func summon(_t, _d) -> void:
	rig.play("Idle_Shield_Break", {"speed": 1.2})
	Audio.sfx("roar", 0.6)
	Game.emit_ev("summonShadows", 4 if phase >= 2 else 3)
	done(1.6)
