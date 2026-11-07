class_name Thug
extends Enemy
## Capanga de Darius (espada, clava, machado) ou sombra de Krauser.

var shadow := false
var heavy_type := false

func setup_thug(o := {}) -> void:
	shadow = o.get("shadow", false)
	var seed: int = o.get("seed", randi() % 1000)
	var w: String = o.get("weapon", "")
	heavy_type = (w == "hammer_A" or w == "axe_A") if w != "" else (seed % 3 == 2 and not shadow)
	if heavy_type and w == "":
		w = "hammer_A"
	var rig_opts := {"seed": seed}
	if w != "":
		rig_opts["weapon"] = w
	if shadow:
		rig_opts["scale"] = 2.1 if o.get("giant", false) else 1.05
	setup_enemy("shadow" if shadow else "thug", {"hp": o.get("hp", 42.0), "dmg": o.get("dmg", 9.0), "speed": o.get("speed", 3.6), "pos": o.get("pos", Vector3.ZERO), "yaw": o.get("yaw", 0.0), "rig": rig_opts, "bleeds": not shadow})
	if shadow:
		corpse_time = 0.2
		flash_col = Color(1, 0.12, 0.3)

func think(delta: float) -> void:
	var t = target
	if t == null:
		return
	var d := Game.dist2d(global_position, t.global_position)
	if shadow and randf() < delta * 6.0:
		Game.fx.burst("shadow", global_position + Vector3(0, randf_range(0.3, 1.6), 0), {"n": 1, "r": 0.3})
	match ai:
		"spawn":
			brake(delta)
			if ai_t > 0.6: ai = "approach"
		"stun", "hurt":
			brake(delta, 6.0)
			if ai_t > stun_t:
				ai = "circle"; ai_t = 0.0
		"approach":
			if d > 5.5:
				move_dir(dir_to(t.global_position), move_speed, delta)
				face_to(t.global_position, delta, 8.0)
			else:
				ai = "circle"
		"circle":
			if d > 7.0:
				ai = "approach"
				return
			circle_around(delta, t)
			if cd <= 0.0 and (t != Game.player or take_token()):
				ai = "engage"; ai_t = 0.0
			elif cd <= 0.0:
				cd = randf_range(0.3, 0.8)
		"engage":
			face_to(t.global_position, delta, 10.0)
			if d > attack_range + t.radius - 0.2:
				move_dir(dir_to(t.global_position), move_speed * 1.15, delta)
			else:
				start_attack()
			if ai_t > 3.5:
				drop_token(); ai = "circle"; cd = 1.0
		"windup", "attack":
			brake(delta, 10.0)
			if ai == "windup":
				face_to(t.global_position, delta, 5.0)
		"recover":
			brake(delta, 8.0)
			if ai_t > 0.5:
				drop_token(); ai = "circle"; ai_t = 0.0; cd = randf_range(1.6, 3.4)

func start_attack() -> void:
	ai = "windup"
	ai_t = 0.0
	move_vel = Vector3.ZERO
	var anim := "Zombie_Scratch" if shadow else ("Sword_Attack" if heavy_type else "Sword_Regular_A")
	var hit_t := 0.75 if shadow else (0.62 if heavy_type else 0.32)
	var spd := 0.8 if heavy_type else (0.9 if shadow else 0.6)
	if heavy_type:
		tel = Game.fx.telegraph({"shape": "circle", "pos": global_position + forward() * 1.6, "radius": 1.4}, hit_t / spd)
	Game.after(0.3 if heavy_type else 0.2, func(): if alive and ai == "windup": glint())
	rig.play(anim, {"speed": spd, "events": {hit_t: "hit"}, "on_event": func(_e): _strike(), "on_end": func():
		if ai == "attack" or ai == "windup":
			ai = "recover"; ai_t = 0.0})

func _strike() -> void:
	if not alive or ai != "windup":
		return
	ai = "attack"
	cancel_attack()
	Audio.sfx("swingHeavy" if heavy_type else "swing", 0.8)
	var reach := 2.6 if heavy_type else attack_range + 0.4
	Game.fx.slash(global_position + Vector3(0, 1.1, 0), yaw, {"color": Color(1, 0.12, 0.3) if shadow else Color(1, 0.7, 0.5), "intensity": 1.2, "roll": 1.5 if heavy_type else 0.6, "scale": 0.9, "dark": shadow})
	for a in Game.allies_of_player():
		var d := Game.dist2d(global_position, a.global_position)
		if d < reach + a.radius and abs(Game.ang_diff(Game.yaw_to(global_position, a.global_position), yaw)) < 1.0:
			Game.damage(self, a, dmg * (1.6 if heavy_type else 1.0), {"heavy": heavy_type, "knock": 8.0 if heavy_type else 4.0})
	if heavy_type:
		Game.fx.burst("dust", global_position + forward() * 1.6, {"n": 10})
		Game.cam.shake(0.15)

func die(src = null) -> void:
	super.die(src)
	if shadow:
		Game.fx.burst("shadow", global_position + Vector3(0, 1, 0), {"n": 30, "r": 0.5, "speed": 2.0, "size": 1.3})
		rig.set_dissolve(0.5)
