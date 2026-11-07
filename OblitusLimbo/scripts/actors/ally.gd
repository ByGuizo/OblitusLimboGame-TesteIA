class_name Ally
extends Actor
## Companheiros no Vale (Near, Amnon, Darin, Calista).

var role := "melee"
var cd := 1.5
var ang := 0.0
var downed := 0.0
var down_text := "Argh...!"
var extra: Callable

func setup_ally(id: String, o := {}) -> void:
	setup(id, {"team": "player", "hp": 200.0, "radius": 0.4, "pos": o.get("pos", Vector3.ZERO), "yaw": o.get("yaw", 0.0), "name": o.get("name", id), "rig": o.get("rig", {})})
	team = "player"
	role = o.get("role", "melee")
	ang = o.get("ang", randf() * TAU)
	cd = randf_range(1.0, 2.5)
	rig.combat = true

func on_hit(_src, _amount: float, o: Dictionary) -> void:
	if downed > 0.0:
		return
	if o.get("heavy", false):
		rig.play("Hit_Chest")

func die(_src = null) -> void:
	hp = 1.0
	knock_down(7.0)

func knock_down(t: float) -> void:
	downed = t
	untargetable = true
	rig.play("Death01", {"hold": true, "speed": 1.4})
	if Game.ui: Game.ui.bark(char_id, down_text)

func _physics_process(delta: float) -> void:
	if Game.cine or scripted:
		brake(delta, 8.0)
		base_update(delta)
		return
	if downed > 0.0:
		downed -= delta
		move_vel = Vector3.ZERO
		if downed <= 0.0:
			rig.play("LayToIdle", {"speed": 1.2})
			hp = max_hp * 0.6
			untargetable = false
		base_update(delta)
		return
	hp = min(max_hp, hp + delta * 3.0)
	var tgt = Game.boss if Game.boss and is_instance_valid(Game.boss) and Game.boss.alive else Game.nearest_enemy(self, 40.0)
	if tgt == null:
		brake(delta)
		base_update(delta)
		return
	ang += delta * 0.25
	var want: float = (tgt.radius + 1.6) if role == "melee" else 8.5
	var goal: Vector3 = tgt.global_position + Vector3(cos(ang) * want, 0, sin(ang) * want)
	var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	var d := to.length()
	if not rig.is_busy():
		if d > 0.4:
			move_dir(to.normalized(), min(5.5, d * 2.0), delta, 8.0)
		else:
			brake(delta)
		face_to(tgt.global_position, delta, 8.0)
	else:
		brake(delta, 6.0)
	cd -= delta
	var rng: float = (tgt.radius + 2.6) if role == "melee" else 16.0
	if cd <= 0.0 and Game.dist2d(global_position, tgt.global_position) < rng:
		cd = randf_range(1.4, 2.8)
		attack(tgt)
	if extra.is_valid():
		extra.call(delta)
	base_update(delta)

func attack(tgt) -> void:
	snap_face(tgt.global_position)
	if role == "ranged":
		rig.play("Spell_Simple_Shoot", {"speed": 0.9, "events": {0.22: "hit"}, "on_event": func(_e):
			if not is_instance_valid(tgt): return
			var s := rig.bone_world("hand_l")
			var red := char_id == "calista"
			Audio.sfx("arrow", 0.5)
			Game.spawn_projectile({"kind": "arrow", "pos": s, "vel": (tgt.chest_pos() - s).normalized() * 30.0, "team": "player", "dmg": 8.0 if red else 6.0, "radius": 0.4, "life": 1.5, "src": self, "glow": red, "color": Color(1, 0.12, 0.2), "fury_gain": 0.0, "knock": 1.0,
				"trail": (func(p, _dt): Game.fx.burst("magic", p.pos, {"n": 1, "color": Color(1, 0.12, 0.2), "color2": Color(0.4, 0, 0.06), "speed": 0.1, "size": 0.6})) if red else Callable()})})
	else:
		var anim: String = ("Sword_Regular_A" if randf() < 0.5 else "Sword_Regular_B") if char_id == "near" else ("Melee_Hook" if randf() < 0.5 else "Punch_Cross")
		rig.play(anim, {"speed": 1.0, "events": {0.2: "hit"}, "on_event": func(_e):
			if not is_instance_valid(tgt): return
			Audio.sfx("swing", 0.5)
			var col := Color(0.25, 1.0, 0.63) if char_id == "darin" else Color(0.7, 0.45, 1.0)
			Game.fx.slash(global_position + Vector3(0, 1.1, 0), yaw, {"color": col, "intensity": 2.0, "scale": 0.9, "roll": randf_range(-0.8, 0.8)})
			if Game.dist2d(global_position, tgt.global_position) < tgt.radius + 2.8:
				Game.damage(self, tgt, 8.0 if char_id == "darin" else 7.0, {"knock": 0.5, "fury_gain": 0.0, "vol": 0.5})})
