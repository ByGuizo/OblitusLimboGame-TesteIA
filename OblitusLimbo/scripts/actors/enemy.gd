class_name Enemy
extends Actor
## Inimigo base: IA de aproximação/circular/atacar com fichas de ataque (porte de actors.js).

var dmg := 10.0
var move_speed := 3.4
var attack_range := 1.9
var poise_max := 0.0
var poise_cur := 0.0
var cd := 1.0
var token := false
var strafe := 1.0
var ai := "spawn"
var ai_t := 0.0
var stun_t := 0.0
var circle_r := 3.6
var target = null
var retarget := 4.0
var ally_aggro := false
var corpse_time := 6.0
var flash_col := Color.WHITE
var tel = null

func setup_enemy(id: String, opts := {}) -> void:
	team = "enemy"
	setup(id, opts.merged({"team": "enemy"}))
	dmg = opts.get("dmg", dmg)
	move_speed = opts.get("speed", move_speed)
	attack_range = opts.get("range", attack_range)
	poise_max = opts.get("poise", 0.0)
	poise_cur = poise_max
	cd = randf_range(0.6, 2.0)
	strafe = 1.0 if randf() < 0.5 else -1.0
	circle_r = randf_range(3.0, 4.2)
	bleeds = opts.get("bleeds", true)
	rig.combat = true

func pick_target():
	if ally_aggro and randf() < 0.45:
		var al := []
		for a in Game.allies_of_player():
			if a != Game.player and not a.get("downed"):
				al.append(a)
		if al.size() > 0:
			return al[randi() % al.size()]
	return Game.player

func take_token() -> bool:
	if token:
		return true
	if Game.attack_tokens < Game.max_tokens:
		Game.attack_tokens += 1
		token = true
		return true
	return false

func drop_token() -> void:
	if token:
		Game.attack_tokens = max(0, Game.attack_tokens - 1)
		token = false

func cancel_attack() -> void:
	if tel and is_instance_valid(tel):
		tel.queue_free()
	tel = null

func stun(t: float) -> void:
	if not alive or get("unstoppable"):
		return
	drop_token()
	stun_t = t
	ai = "stun"
	ai_t = 0.0
	rig.play("Hit_Knockback" if t > 1.0 else "Hit_Chest", {"speed": 0.8 if t > 1.0 else 1.0})
	cancel_attack()

func on_freeze(t: float) -> void:
	stun(t)
	rig.set_action_speed(0.0)

func on_unfreeze() -> void:
	rig.set_action_speed(1.0)

func on_hit(_src, amount: float, o: Dictionary) -> void:
	if not alive:
		return
	if poise_max > 0.0:
		poise_cur -= amount * (1.5 if o.get("heavy", false) else 1.0)
		if poise_cur <= 0.0:
			poise_cur = poise_max
			stun(1.8)
			if Game.ui: Game.ui.toast("ATORDOADO", Color(1, 0.82, 0.38), 0.8)
		return
	if ai == "windup" and not o.get("heavy", false) and randf() < 0.5:
		return
	if not o.get("fx", true):
		return
	drop_token()
	var left: float = maxf(0.0, stun_t - ai_t) if ai == "hurt" else 0.0
	ai = "hurt"
	ai_t = 0.0
	var r: String = o.get("reaction", "knockback" if o.get("heavy", false) and amount > 20.0 else "flinch")
	match r:
		"launch":
			stun_t = 1.0
			rig.play("Hit_Knockback", {"speed": 0.9, "blend": 0.05})
		"knockback":
			stun_t = 0.75
			rig.play("Hit_Knockback", {"speed": 1.15, "blend": 0.05})
		"stagger":
			stun_t = 0.5
			rig.play("Hit_Head", {"speed": 1.0, "blend": 0.05})
		_:
			stun_t = 0.3
			rig.play("Hit_Chest" if randf() < 0.5 else "Hit_Head", {"speed": 1.4, "blend": 0.04})
	stun_t = maxf(stun_t, minf(left + 0.12, 1.2))
	cancel_attack()

func die(src = null) -> void:
	if dead:
		return
	drop_token()
	cancel_attack()
	super.die(src)
	Game.kill_count += 1
	Game.emit_ev("kill", self)
	vanish(corpse_time, 1.5)

func _physics_process(delta: float) -> void:
	if not alive:
		brake(delta, 5.0)
		base_update(delta)
		return
	if st_blind > 0.0:
		# cego (fumaça): perde o alvo e fica parado
		brake(delta, 6.0)
		base_update(delta)
		return
	retarget -= delta
	if retarget <= 0.0 and not get("busy"):
		retarget = randf_range(4.0, 7.0)
		target = pick_target()
	if target == null or not is_instance_valid(target) or not target.alive or target.get("downed"):
		target = pick_target()
	if Game.cine or scripted or Game.player == null:
		brake(delta, 8.0)
		base_update(delta)
		return
	ai_t += delta
	cd -= delta
	think(delta)
	base_update(delta)

func think(_delta: float) -> void:
	pass

func glint() -> void:
	var h := rig.bone_world("hand_r")
	Game.fx.burst("spark", h, {"n": 6, "color": Color(1, 1, 1), "color2": Color(1, 0.2, 0.12)})
	# brilho de aviso estilo anime: estrela grande que pisca na arma
	Game.fx.emit("star", h, Vector3.ZERO, 0.32, 1.1, Color(1, 0.9, 0.85))
	Game.fx.emit("star", h, Vector3.ZERO, 0.22, 0.6, Color(1, 0.3, 0.2))
	Game.fx.flash(h, Color(1, 0.25, 0.12), 3.0, 0.25, 4.0)
	Audio.sfx("telegraph", 0.5)

func circle_around(delta: float, t) -> void:
	var tp: Vector3 = t.global_position
	var d := Game.dist2d(global_position, tp)
	var to_t := Vector3(tp.x - global_position.x, 0, tp.z - global_position.z).normalized()
	var side := Vector3(-to_t.z, 0, to_t.x) * strafe
	var radial: float = clamp((d - circle_r) * 0.8, -1.0, 1.0)
	var dir := side * 0.7 + to_t * radial
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	move_dir(dir, move_speed * 0.45, delta, 6.0)
	face_to(tp, delta, 8.0)
	if randf() < delta * 0.3:
		strafe *= -1.0

func dir_to(p: Vector3) -> Vector3:
	return Vector3(p.x - global_position.x, 0, p.z - global_position.z).normalized()
