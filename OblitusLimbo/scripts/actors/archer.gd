class_name Archer
extends Enemy
## Besteiro: mantém distância, mira com um laser vermelho e dispara.

var laser: MeshInstance3D

func setup_archer(o := {}) -> void:
	setup_enemy("thug", {"hp": 32.0, "dmg": 8.0, "speed": 3.2, "pos": o.get("pos", Vector3.ZERO), "rig": {"seed": o.get("seed", 4), "weapon": "bow"}})
	circle_r = randf_range(8.0, 10.0)

func cancel_attack() -> void:
	if laser and is_instance_valid(laser):
		laser.queue_free()
	laser = null

func think(delta: float) -> void:
	var t = target
	if t == null:
		return
	var d := Game.dist2d(global_position, t.global_position)
	match ai:
		"spawn":
			if ai_t > 0.6: ai = "circle"
		"stun", "hurt":
			brake(delta, 6.0)
			if ai_t > stun_t:
				ai = "circle"; ai_t = 0.0
		"circle":
			if d < 5.0:
				move_dir(-dir_to(t.global_position), move_speed, delta)
				face_to(t.global_position, delta, 6.0)
			else:
				circle_around(delta, t)
			if cd <= 0.0 and d < 16.0:
				ai = "aim"; ai_t = 0.0
				rig.play("Pistol_Aim_Neutral", {"hold": true, "blend": 0.15})
				rig.pose.set_offset("upperarm_l", Vector3(0, 0, 0), 0.0)
		"aim":
			brake(delta, 8.0)
			face_to(t.global_position, delta, 6.0)
			var from := rig.bone_world("hand_l")
			var to: Vector3 = t.chest_pos()
			if laser == null:
				laser = Game.fx.laser()
				Game.world.add_child(laser)
			Game.fx.place_beam(laser, from, to, 0.2 + min(1.0, ai_t / 0.9) * 0.6 + (sin(ai_t * 60.0) * 0.3 if ai_t > 0.75 else 0.0))
			if ai_t > 0.95:
				cancel_attack()
				Audio.sfx("arrow")
				Game.spawn_projectile({"kind": "bolt", "pos": from, "vel": (to - from).normalized() * 26.0, "team": "enemy", "dmg": dmg, "radius": 0.35, "life": 2.0, "src": self, "knock": 2.0})
				rig.stop_action(0.2)
				ai = "recover"; ai_t = 0.0
		"recover":
			if ai_t > 0.6:
				ai = "circle"; cd = randf_range(2.5, 4.0)
