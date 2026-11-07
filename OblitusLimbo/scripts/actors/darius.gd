class_name Darius
extends Boss
## Darius — o maior criminoso de Vardun.

func setup_darius(o := {}) -> void:
	setup_boss("darius", {"hp": o.get("hp", 720.0), "dmg": 20.0, "speed": 2.7, "poise": 110.0, "radius": 0.75, "title": "O Maior Criminoso de Vardun", "pos": o.get("pos", Vector3.ZERO), "yaw": o.get("yaw", 0.0), "name": "Darius"})
	pref_dist = 2.6
	cd_base = 1.4
	attacks = [
		{"w": 3.0, "max": 3.6, "cd": 2.5, "fn": cleave},
		{"w": 3.0, "max": 3.4, "cd": 3.0, "fn": sweep},
		{"w": 2.0, "min": 4.5, "cd": 6.0, "fn": charge},
		{"w": 1.5, "max": 6.0, "cd": 9.0, "fn": slam},
		{"w": 2.0, "max": 4.0, "cd": 7.0, "fn": triple, "phase": [2]},
	]
	corpse_time = 30.0

func check_phase() -> void:
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		move_speed *= 1.2
		cd_base = 1.0
		clear_pending()
		busy = true
		busy_unstoppable = true
		ai = "attack"
		rig.play("Idle_Shield_Break", {"speed": 0.8})
		Audio.sfx("roar")
		Game.cam.shake(0.6)
		Game.emit_ev("bossPhase", {"boss": self, "phase": 2})
		Game.after(1.6, func(): busy_unstoppable = false; done(0.0))

func cleave(t, _d) -> void:
	snap_face(t.global_position)
	var p := global_position
	var y := yaw
	queue_area({"shape": "rect", "pos": p, "yaw": y, "width": 1.6, "length": 3.6, "delay": 0.85, "dmg": dmg * 1.1, "knock": 9.0,
		"on_trigger": func(_s):
			Game.fx.burst("dust", p + Game.fwd(y) * 2.6, {"n": 14, "size": 1.2})
			Game.fx.burst("spark", p + Game.fwd(y) * 2.6 + Vector3(0, 0.2, 0), {"n": 14})
			Game.fx.cracks(p + Game.fwd(y) * 2.6, 2.2, Color(1, 0.45, 0.15), 3.0)
			Game.fx.impact(p + Game.fwd(y) * 2.6 + Vector3(0, 0.3, 0), Color(1, 0.7, 0.4), 1.8)
			Game.cam.shake(0.35)
			Audio.sfx("hitHeavy", 0.6)})
	rig.play("Sword_Attack", {"speed": 0.85, "events": {0.5: "trail", 0.62: "hit"}, "on_event": func(e):
		if e == "trail":
			Game.fx.trail(rig, Color(1, 0.6, 0.3), 0.35)
			return
		Audio.sfx("swingHeavy")
		Game.fx.slash(global_position + Vector3(0, 1.6, 0), y, {"roll": 1.55, "big": true, "color": Color(1, 0.7, 0.44), "intensity": 1.4, "scale": 1.2})})
	done(1.4)

func sweep(t, _d) -> void:
	snap_face(t.global_position)
	var p := global_position
	var y := yaw
	queue_area({"shape": "cone", "pos": p, "yaw": y, "radius": 3.6, "angle": 2.8, "delay": 0.6, "dmg": dmg * 0.8, "knock": 8.0})
	rig.play("Sword_Regular_B", {"speed": 0.55, "events": {0.2: "hit"}, "on_event": func(_e):
		Game.fx.trail(rig, Color(1, 0.6, 0.3), 0.4)
		Audio.sfx("swingHeavy")
		Game.fx.slash(global_position + Vector3(0, 1.4, 0), y, {"roll": 0.0, "big": true, "color": Color(1, 0.7, 0.44), "intensity": 1.4, "scale": 1.3, "flip": true})})
	done(1.1)

func charge(t, _d) -> void:
	snap_face(t.global_position)
	var y := Game.yaw_to(global_position, t.global_position)
	var length: float = min(13.0, Game.dist2d(global_position, t.global_position) + 3.0)
	tel_only({"shape": "rect", "pos": global_position, "yaw": y, "width": 1.8, "length": length}, 0.9)
	rig.play("Idle_Shield_Break", {"speed": 1.2})
	Audio.sfx("roar", 0.6)
	busy_unstoppable = true
	var hit := [false]
	var tt := [0.0]
	Game.after(0.9, func():
		if not alive: return
		yaw = y
		rig.play("Shield_Dash", {"speed": 1.0, "loop": true})
		busy_update = func(dt, _t, _dd):
			tt[0] += dt
			var before := global_position
			move_vel = Game.fwd(y) * 14.0
			if randf() < 0.6: Game.fx.burst("dust", global_position, {"n": 2})
			for a in Game.allies_of_player():
				if not hit[0] and Game.dist2d(a.global_position, global_position) < radius + a.radius + 0.4:
					hit[0] = true
					Game.damage(self, a, dmg * 1.2, {"heavy": true, "knock": 13.0})
			var moved: float = Game.dist2d(before, global_position) / max(dt, 0.0001)
			if tt[0] > length / 14.0 or (tt[0] > 0.25 and moved < 2.0):
				move_vel = Vector3.ZERO
				rig.stop_action(0.1)
				busy_update = Callable()
				busy_unstoppable = false
				if tt[0] > 0.25 and moved < 2.0:
					Game.cam.shake(0.5); Audio.sfx("hitHeavy")
					busy = false
					stun(1.6)
					if Game.ui: Game.ui.toast("Darius se chocou!", Color(1, 0.82, 0.38), 1.0)
				else:
					done(0.5))

func slam(_t, _d) -> void:
	var p := global_position
	busy_unstoppable = true
	queue_area({"pos": p, "radius": 4.8, "delay": 0.95, "dmg": dmg * 0.9, "knock": 12.0,
		"on_trigger": func(_s):
			Game.fx.shockwave(p, Color(1, 0.7, 0.44), 5.5, {"glow": Color(1, 0.45, 0.15)})
			Game.fx.impact(p + Vector3(0, 0.4, 0), Color(1, 0.7, 0.4), 2.6)
			Game.fx.burst("dust", p, {"n": 30, "size": 1.5, "speed": 2.0})
			Game.cam.shake(0.7)
			Audio.sfx("explosion", 0.6)})
	rig.play("OverhandThrow", {"speed": 0.75, "on_end": func(): busy_unstoppable = false})
	done(1.8)

func triple(_t, _d) -> void:
	var n := [0]
	_triple_step(n)
	done(2.6)

func _triple_step(n: Array) -> void:
	if not alive or ai == "stun":
		return
	snap_face(target.global_position)
	var p := global_position
	var y := yaw
	queue_area({"shape": "rect", "pos": p, "yaw": y, "width": 1.6, "length": 3.4, "delay": 0.62, "dmg": dmg * 0.9, "knock": 7.0})
	var anims := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_A"]
	rig.play(anims[n[0] % 3], {"speed": 0.7, "events": {0.2: "hit"}, "on_event": func(_e):
		Game.fx.trail(rig, Color(1, 0.5, 0.25), 0.35)
		Audio.sfx("swingHeavy")
		Game.fx.slash(global_position + Vector3(0, 1.5, 0), y, {"roll": 1.2 * (-1.0 if n[0] % 2 else 1.0), "big": true, "color": Color(1, 0.56, 0.31), "intensity": 1.4})})
	n[0] += 1
	if n[0] < 3:
		Game.after(0.75, func(): _triple_step(n))
