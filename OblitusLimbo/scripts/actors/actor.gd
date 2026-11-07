class_name Actor
extends CharacterBody3D
## Ator base: corpo físico + personagem montado + estado de combate.

var rig: CharRig
var char_id := ""
var team := "enemy"
var display_name := ""
var hp := 100.0
var max_hp := 100.0
var alive := true
var dead := false
var radius := 0.42
var height := 1.8
var yaw := 0.0
var move_vel := Vector3.ZERO
var knock := Vector3.ZERO
var vy := 0.0
var iframes := 0.0
var invulnerable := false
var untargetable := false
var guarding := false
var guard_t := 0.0
var stamina := 100.0
var resist := {}
var dmg_taken_mul := 1.0
var min_hp := -1.0
var knock_resist := 1.0
var bleeds := true
var last_hit_by = null
var state := "idle"
var state_t := 0.0
var flying := false
var fly_height := 0.0
var resonance := 0
var big := false
var boss := false
var speed := 0.0
var scripted := false
var sprinting := false
var _col: CollisionShape3D
# estados: lentidão, raiz (preso), congelado, cego e frio acumulado (Viktor)
var st_slow := 0.0
var st_slow_k := 1.0
var st_root := 0.0
var st_freeze := 0.0
var st_blind := 0.0
var frost := 0.0
var freeze_immune := false      # ex.: Frio Absoluto de Krauser
var _ice_block: Node3D = null

func setup(id: String, opts := {}) -> void:
	char_id = id
	display_name = opts.get("name", id)
	team = opts.get("team", team)
	max_hp = opts.get("hp", max_hp)
	hp = max_hp
	radius = opts.get("radius", radius)
	knock_resist = opts.get("knock_resist", knock_resist)
	rig = CharFactory.build(id, opts.get("rig", {}))
	add_child(rig)
	height = rig.height
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = max(height * 0.95, radius * 2.0 + 0.1)
	_col.shape = cap
	_col.position.y = cap.height * 0.5
	add_child(_col)
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	if opts.has("pos"):
		position = opts.pos
	yaw = opts.get("yaw", 0.0)
	rotation.y = yaw

func _enter_tree() -> void:
	if not Game.actors.has(self):
		Game.actors.append(self)

func _exit_tree() -> void:
	Game.actors.erase(self)

func forward() -> Vector3:
	return Game.fwd(yaw)

func chest_pos() -> Vector3:
	return global_position + Vector3(0, height * 0.65, 0)

func head_pos(off := 0.0) -> Vector3:
	return global_position + Vector3(0, height * 0.92 + off, 0)

func set_state(s: String) -> void:
	state = s
	state_t = 0.0

func face_to(target, delta: float, rate := 10.0) -> void:
	var want: float = target if (typeof(target) == TYPE_FLOAT) else Game.yaw_to(global_position, target)
	var d := Game.ang_diff(want, yaw)
	yaw += clamp(d, -rate * delta, rate * delta)

func snap_face(target) -> void:
	yaw = target if (typeof(target) == TYPE_FLOAT) else Game.yaw_to(global_position, target)
	rotation.y = yaw

func speed_mul() -> float:
	if st_root > 0.0 or st_freeze > 0.0:
		return 0.0
	return st_slow_k if st_slow > 0.0 else 1.0

## Aplica um estado: slow (v = multiplicador de velocidade), root, freeze, blind.
func apply_status(kind: String, t: float, v := 0.0) -> void:
	if not alive:
		return
	if (kind == "freeze" or kind == "slow") and (freeze_immune or get("armor") == true):
		return
	match kind:
		"slow":
			st_slow = maxf(st_slow, t)
			st_slow_k = v if v > 0.0 else 0.55
		"root":
			st_root = maxf(st_root, t)
		"blind":
			st_blind = maxf(st_blind, t)
		"freeze":
			if st_freeze <= 0.0:
				st_freeze = t
				_ice_block = Game.fx.ice_block(self) if Game.fx and Game.fx.has_method("ice_block") else null
				on_freeze(t)
			else:
				st_freeze = maxf(st_freeze, t)

## Frio acumulado: ao chegar a 100 o alvo vira um bloco de gelo.
func add_frost(v: float, freeze_t := 1.3) -> void:
	if not alive or st_freeze > 0.0 or freeze_immune or get("armor") == true:
		return
	frost = minf(100.0, frost + v)
	if frost >= 100.0:
		frost = 0.0
		apply_status("freeze", freeze_t)

## Quebra o gelo antes do tempo (estilhaçar).
func break_freeze() -> void:
	if st_freeze <= 0.0:
		return
	st_freeze = 0.0
	_end_freeze(true)

func _end_freeze(shatter := false) -> void:
	if _ice_block and is_instance_valid(_ice_block):
		Game.fx.ice_block_break(_ice_block, shatter)
	_ice_block = null
	on_unfreeze()

## Ganchos de congelamento (Player/Enemy sobrescrevem).
func on_freeze(_t: float) -> void:
	pass

func on_unfreeze() -> void:
	pass

func _status_tick(delta: float) -> void:
	st_slow = maxf(0.0, st_slow - delta)
	st_root = maxf(0.0, st_root - delta)
	st_blind = maxf(0.0, st_blind - delta)
	frost = maxf(0.0, frost - delta * 6.0)
	if st_freeze > 0.0:
		st_freeze -= delta
		if st_freeze <= 0.0:
			st_freeze = 0.0
			_end_freeze(false)

func move_dir(dir: Vector3, spd: float, delta: float, accel := 12.0) -> void:
	spd *= speed_mul()
	var k := 1.0 - exp(-accel * delta)
	move_vel.x += (dir.x * spd - move_vel.x) * k
	move_vel.z += (dir.z * spd - move_vel.z) * k

func brake(delta: float, k := 8.0) -> void:
	move_vel *= exp(-k * delta)

func base_update(delta: float) -> void:
	_status_tick(delta)
	knock *= exp(-delta * 7.0)
	if flying:
		vy = (fly_height - global_position.y) * 6.0
	elif is_on_floor() and vy <= 0.0:
		vy = -0.5
	else:
		vy -= 22.0 * delta
	velocity = Vector3(move_vel.x + knock.x, vy, move_vel.z + knock.z)
	if delta > 0.0:
		move_and_slide()
	rotation.y = yaw
	speed = Vector2(move_vel.x, move_vel.z).length()
	state_t += delta
	if iframes > 0.0:
		iframes -= delta
	if rig:
		rig.set_loco(speed if alive else 0.0, sprinting)

func teleport(p: Vector3) -> void:
	global_position = p
	if rig:
		rig.reset_cloth()

# ---- ganchos sobrescritos pelas subclasses ----
func on_hit(_src, _amount: float, _o: Dictionary) -> void:
	pass

func stun(_t: float) -> void:
	pass

func gain_fury(_v: float) -> void:
	pass

func guard_break() -> void:
	pass

func die(_src = null) -> void:
	if dead:
		return
	dead = true
	alive = false
	if st_freeze > 0.0:
		st_freeze = 0.0
		_end_freeze(true)
	collision_layer = 0
	collision_mask = 1
	if rig:
		rig.play("Death01", {"hold": true, "blend": 0.1})
	Audio.sfx("die", 0.7)
	Game.emit_ev("death", self)

## Dissolve e remove (sombras, inimigos após um tempo)
func vanish(after := 4.0, dur := 1.2) -> void:
	await get_tree().create_timer(after, false).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_method(func(v): if rig: rig.set_dissolve(v), 0.0, 1.0, dur)
	await tw.finished
	if is_instance_valid(self):
		queue_free()
