class_name Boss
extends Enemy
## Chefe base: escolhe ataques ponderados por distância/fase; ataques são "ocupados".

var attacks: Array = []
var busy := false
var busy_update: Callable
var unstoppable := false
var busy_unstoppable := false
var title := ""
var phase := 1
var pref_dist := 2.4
var cd_base := 1.6
var pend: Array = []
var phase_lock := false

func setup_boss(id: String, opts := {}) -> void:
	setup_enemy(id, opts)
	big = true
	boss = true
	knock_resist = 0.15
	title = opts.get("title", "")
	Game.boss = self

func stun(t: float) -> void:
	if busy_unstoppable:
		return
	super.stun(t)
	busy = false
	busy_update = Callable()
	clear_pending()

func clear_pending() -> void:
	for a in pend:
		if typeof(a) == TYPE_DICTIONARY:
			Game.cancel_area(a)
		elif typeof(a) == TYPE_OBJECT and is_instance_valid(a):
			a.queue_free()
	pend = []

func queue_area(o: Dictionary) -> Dictionary:
	var a := Game.area_attack(o.merged({"team": "enemy", "src": self}))
	pend.append(a)
	return a

func tel_only(s: Dictionary, time: float, col := Color(1, 0.16, 0.12)) -> void:
	pend.append(Game.fx.telegraph(s, time, col))

func choose_attack(d: float):
	var opts := []
	var tot := 0.0
	for a in attacks:
		if a.get("min", 0.0) <= d and d <= a.get("max", 99.0) and a.get("cd_left", 0.0) <= 0.0 and (not a.has("phase") or phase in a.phase):
			opts.append(a); tot += a.w
	if opts.is_empty():
		return null
	var r := randf() * tot
	for a in opts:
		r -= a.w
		if r <= 0.0:
			return a
	return opts[0]

func think(delta: float) -> void:
	for a in attacks:
		a["cd_left"] = a.get("cd_left", 0.0) - delta
	var t = target
	if t == null:
		return
	var d := Game.dist2d(global_position, t.global_position)
	if ai == "stun" or ai == "hurt":
		brake(delta, 6.0)
		if ai_t > stun_t:
			ai = "chase"; ai_t = 0.0
		return
	if ai == "spawn":
		if ai_t > 0.5: ai = "chase"
		return
	if busy:
		if busy_update.is_valid():
			busy_update.call(delta, t, d)
		else:
			brake(delta, 6.0)
		return
	var dir := dir_to(t.global_position)
	if d > pref_dist:
		move_dir(dir, move_speed, delta, 6.0)
	else:
		move_dir(Vector3(-dir.z, 0, dir.x) * strafe, move_speed * 0.3, delta, 4.0)
	face_to(t.global_position, delta, 4.0)
	if cd <= 0.0:
		var a = choose_attack(d)
		if a:
			a["cd_left"] = a.get("cd", 3.0)
			busy = true
			ai = "attack"
			ai_t = 0.0
			move_vel = Vector3.ZERO
			(a.fn as Callable).call(t, d)
			cd = cd_base * randf_range(0.7, 1.2)
		else:
			cd = 0.3

func done(after := 0.4) -> void:
	Game.after(after, func():
		if alive:
			busy = false
			busy_update = Callable()
			ai = "chase"
			unstoppable = false)

func on_hit(_src, amount: float, o: Dictionary) -> void:
	if not alive:
		return
	poise_cur -= amount * (1.4 if o.get("heavy", false) else 1.0)
	if poise_cur <= 0.0 and not busy_unstoppable:
		poise_cur = poise_max
		stun(2.2)
		if Game.ui: Game.ui.toast("ATORDOADO!", Color(1, 0.82, 0.38), 1.0)
	check_phase()

func check_phase() -> void:
	pass

func die(src = null) -> void:
	clear_pending()
	super.die(src)
	Game.emit_ev("bossDead", self)
