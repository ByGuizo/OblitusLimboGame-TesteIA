class_name Player
extends Actor
## Lutador jogável. Tudo o que é específico do personagem vem do kit (scripts/combat/kits/kit_<id>.gd).

var kit := "kiana"
var fk: FighterKit                # kit do personagem
var K: Dictionary
var awakened := false             # despertar ativo (Apagão, Domínio do Inverno…)
var energy := 100.0
var max_energy := 100.0
var max_stamina := 100.0
var fury := 0.0
var potions := 3
var combo := 0
var combo_t := 0.0
var buffer := ""                 # primeiro comando pendente (compatibilidade)
var buffer_t := 0.0
var queue: Array = []            # fila de entradas [{c, t}] (máx. 2, validade 0,35 s)
var moves: Dictionary            # MoveSet do personagem
var cur_move := {}
var cur_move_id := ""
var counter_t := 0.0             # janela de contra-ataque após esquivar
var fury_hold := -1.0            # tempo segurando F (-1 = solto)
var fury_hold_used := false
var cd := [0.0, 0.0, 0.0]
var lock_target = null
var controllable := true
var stamina_delay := 0.0
var heal_t := 0.0
var fury_active := 0.0
var ult = null
var exhausted := 0.0
var combat_t := 0.0
var dodge_t := 9.0
var dodge_dir := Vector3.FORWARD
var perfect_used := false

var lunge_t := 0.0
var lunge_spd := 0.0
var cast_dur := 0.0
var cast_move := 0.0
var state_lock := 0.3
var was_guard := false
var wish := Vector3.ZERO
var skills: Array = []
var boss_near := false
var _step_t := 0.0
var aura_node = null
# --- modo Versus ---
var brain = null                 # VersusBot: entradas virtuais (CPU); null = teclado/mouse
var versus := false
var opponent = null
var subs := 4.0                  # barras de Substituição (máx. 4)
var chase_t := 0.0               # investida de chakra em andamento
var chase_window := 0.0          # logo após a investida, o leve vira golpe de investida
var charging := false
var combo_hits := 0              # golpes seguidos recebidos (contador de combo do oponente)

func setup_player(k: String, opts := {}) -> void:
	kit = k
	fk = Kits.make(k, self)
	K = fk.stats()
	moves = fk.moves()
	team = "player"
	max_hp = K.hp
	setup(Kits.model(k), {"team": team, "hp": K.hp, "radius": K.get("radius", 0.36), "pos": opts.get("pos", Vector3.ZERO), "yaw": opts.get("yaw", 0.0), "name": K.name})
	stamina = max_stamina
	skills = fk.skills()
	collision_layer = 2
	fk.setup()

func _exit_tree() -> void:
	super._exit_tree()
	if fk:
		fk.cleanup()

func dmg_mul() -> float:
	return fk.dmg_mul() * (0.6 if exhausted > 0.0 else 1.0)

func fury_name() -> String:
	return fk.awaken_name()

func gain_fury(v: float) -> void:
	if fury_active > 0.0 or ult != null:
		return
	var before := fury
	fury = min(100.0, fury + v * float(K.get("fury_gain", 1.0)) * (0.45 if versus else 1.0))
	if before < 100.0 and fury >= 100.0:
		Audio.sfx("heartbeat")
		_say("FÚRIA CHEIA — [F] ULTIMATE" + (" · SEGURE [F] " + fury_name() if fk.has_awaken() else ""), Color(1, 0.3, 0.23))

func guard_break() -> void:
	guarding = false
	rig.play("Hit_Knockback", {"speed": 1.2})
	set_state("hit"); state_lock = 0.8
	Audio.sfx("hitHeavy")
	_say("GUARDA QUEBRADA", Color(1, 0.5, 0.38))

func on_hit(src, amount: float, o: Dictionary) -> void:
	combat_t = 4.0
	if versus:
		_versus_react(src, amount, o)
		return
	if ult != null or state == "cine" or state == "dodge":
		return
	if st_freeze > 0.0 or fk.super_armor():
		return
	if not o.get("fx", true) or amount < 5.0:
		return
	if o.get("heavy", false) and amount > 12.0 and not guarding:
		rig.play("Hit_Knockback", {"speed": 1.1})
		set_state("hit"); state_lock = 0.75; iframes = 0.8
	elif not guarding:
		if state != "attack" or amount > 10.0:
			rig.play("Hit_Chest" if randf() < 0.5 else "Hit_Head", {"speed": 1.0})
			set_state("hit"); state_lock = 0.3
	Audio.sfx("hurt", 0.8)

func die(src = null) -> void:
	if dead:
		return
	hp = 0.0
	end_fury()
	super.die(src)
	Game.slow(2.0, 0.3)
	Game.after(1.6, func(): Game.emit_ev("playerDead"))

# ---------------------------------------------------------------------
#  Entradas (teclado ou CPU)
# ---------------------------------------------------------------------
func _in_just(a: String) -> bool:
	return brain.just(a) if brain else Input.is_action_just_pressed(a)

func _in_held(a: String) -> bool:
	return brain.held(a) if brain else Input.is_action_pressed(a)

func _say(text: String, col := Color.WHITE, dur := 1.2, big := false) -> void:
	if Game.ui and brain == null:
		Game.ui.toast(text, col, dur, big)

# ---------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not alive:
		brake(delta, 4.0)
		base_update(delta)
		return
	var ctl: bool = controllable and not scripted and not Game.cine and not get_tree().paused
	if brain and ctl:
		brain.tick(delta)
	if versus:
		_versus_tick(delta)
	for i in 3:
		cd[i] = max(0.0, cd[i] - delta)
	combo_t -= delta
	if combo_t <= 0.0:
		combo = 0
	combat_t -= delta
	stamina_delay -= delta
	exhausted -= delta
	dodge_t += delta
	energy = min(max_energy, energy + delta * (2.0 if exhausted > 0.0 else 7.0))
	if stamina_delay <= 0.0 and not sprinting:
		stamina = min(max_stamina, stamina + delta * (8.0 if exhausted > 0.0 else 30.0))
	if heal_t > 0.0:
		heal_t -= delta
		hp = min(max_hp, hp + delta * 32.0)
		if randf() < 0.5: Game.fx.burst("heal", global_position, {"n": 1})
	if lock_target and (not is_instance_valid(lock_target) or not lock_target.alive):
		lock_target = Game.nearest_enemy(self, 18.0)
	if fury_active > 0.0:
		_update_fury(delta)
	if ult != null:
		_update_ult(delta)
	rig.combat = combat_t > 0.0 or lock_target != null or Game.in_combat
	# movimento desejado relativo à câmera
	var mx := 0.0
	var mz := 0.0
	if ctl and brain == null:
		mz = Input.get_action_strength("move_f") - Input.get_action_strength("move_b")
		mx = Input.get_action_strength("move_r") - Input.get_action_strength("move_l")
	var cy: float = Game.cam.yaw if Game.cam else 0.0
	var f := Game.fwd(cy)
	var r := Vector3(-cos(cy), 0, sin(cy))
	wish = f * mz + r * mx
	if brain:
		wish = brain.move if ctl else Vector3.ZERO
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	# entradas → fila com validade (nenhum aperto é perdido durante animações)
	if ctl:
		if _in_just("lock") and not versus: toggle_lock()
		if _in_just("attack"): _push("light")
		if _in_just("heavy"): _push("heavy")
		if _in_just("dodge"): _push("dodge")
		if _in_just("skill1"): _push("s0")
		if _in_just("skill2"): _push("s1")
		if _in_just("skill3"): _push("s2")
		if _in_just("potion") and not versus: use_potion()
		if versus and _in_just("sprint"): _push("chase")
		_fury_input()
	_expire_queue()
	buffer = _peek()
	counter_t -= delta
	guarding = false
	var s := state
	var guard_held: bool = ctl and _in_held("guard") and stamina > 5.0
	var charge_held: bool = versus and ctl and _in_held("potion") and not guard_held
	if ult != null:
		brake(delta, 6.0)
	elif s == "idle" or s == "move":
		sprinting = ctl and _in_held("sprint") and wish.length_squared() > 0.01 and stamina > 1.0 and not guard_held and (lock_target == null or versus)
		if charge_held and wish.length_squared() < 0.01:
			_start_charge()
		if sprinting:
			stamina -= delta * 16.0
			stamina_delay = 0.5
		var spd: float = 1.8 if guard_held else (K.sprint if sprinting else K.speed)
		spd *= (1.3 if fury_active > 0.0 else 1.0) * (0.6 if exhausted > 0.0 else 1.0) * fk.move_mul()
		move_dir(wish, spd * min(1.0, wish.length() * 1.3), delta, 22.0)
		if lock_target:
			face_to(lock_target.global_position, delta, 16.0)
		elif wish.length_squared() > 0.01:
			face_to(atan2(wish.x, wish.z), delta, 20.0)
		if guard_held:
			_guard_tick(delta)
		elif was_guard:
			rig.stop_action(0.1)
			was_guard = false
		_consume_neutral()
	elif s == "attack":
		_attack_tick(delta, guard_held)
	elif s == "dodge":
		var t := state_t
		var sp: float = max(0.0, 13.5 * (1.0 - t / 0.42))
		move_dir(dodge_dir, sp, delta, 40.0)
		var c := _peek()
		if t > 0.22 and (c == "light" or c == "heavy"):
			rig.stop_action(0.06); set_state("move"); _consume_neutral()
		elif t > 0.3 and c != "":
			rig.stop_action(0.08); set_state("move"); _consume_neutral()
		elif t >= 0.5:
			rig.stop_action(0.15); set_state("move")
	elif s == "cast":
		move_dir(forward(), cast_move, delta, 20.0)
		if state_t >= cast_dur:
			set_state("move")
			_consume_neutral()
		elif state_t >= cast_dur * 0.6 and _peek() == "dodge":
			rig.stop_action(0.08); set_state("move"); _consume_neutral()
	elif s == "charge":
		brake(delta, 10.0)
		_charge_tick(delta, charge_held)
	elif s == "chase":
		_chase_tick(delta)
	elif s == "hit":
		brake(delta, 10.0)
		# Substituição: esquivar durante o atordoamento (Versus)
		if versus and _peek() == "dodge" and state_t > 0.06 and not scripted:
			if subs >= 1.0:
				_pop()
				substitute()
				return
			_pop()
		if state_t >= state_lock and not scripted:
			rig.stop_action(0.12)
			set_state("move")
			_consume_neutral()
	elif s == "cine":
		brake(delta, 8.0)
		was_guard = false
		queue.clear()
	if state != "idle" and state != "move":
		sprinting = false
	if brain:
		brain.post_frame()
	base_update(delta)
	_footsteps(delta)
	_visuals(delta)
	if versus:
		return
	boss_near = Game.boss != null and is_instance_valid(Game.boss) and Game.boss.alive and Game.dist2d(Game.boss.global_position, global_position) < 14.0

func _footsteps(delta: float) -> void:
	if speed > 1.0 and not rig.is_busy():
		_step_t -= delta * (speed / 2.2)
		if _step_t <= 0.0:
			_step_t = 0.34
			Audio.sfx("step_wood" if Game.level and Game.level.surface == "wood" else "step", 1.0 if sprinting else 0.7)

func _visuals(_delta: float) -> void:
	if rig.weapon and rig.weapon.has_meta("glow"):
		var gm: StandardMaterial3D = rig.weapon.get_meta("glow")
		gm.emission_energy_multiplier = 1.8 + sin(Game.time * 4.0) * 0.5 + (2.0 if fury_active > 0.0 else 0.0)
	fk.tick(_delta)

# ---------------------------------------------------------------------
#  Fila de entradas e cancelamentos
# ---------------------------------------------------------------------
func _push(c: String) -> void:
	queue.append({"c": c, "t": Game.time})
	while queue.size() > 2:
		queue.pop_front()

func _expire_queue() -> void:
	while not queue.is_empty() and Game.time - queue[0].t > 0.35:
		queue.pop_front()

func _peek() -> String:
	return queue[0].c if not queue.is_empty() else ""

func _pop() -> String:
	return queue.pop_front().c if not queue.is_empty() else ""

## Executa o próximo comando a partir do estado neutro.
func _consume_neutral() -> void:
	var c := _pop()
	match c:
		"chase": chakra_dash()
		"light":
			if counter_t > 0.0:
				start_move(moves.start.counter)
			elif sprinting or speed > K.speed + 0.8 or chase_window > 0.0:
				start_move(moves.start.dash)
			else:
				start_move(moves.start.light)
		"heavy": start_move(moves.start.heavy)
		"dodge": dodge()
		"s0": use_skill(0)
		"s1": use_skill(1)
		"s2": use_skill(2)

## F: toque = Ultimate (fúria cheia); segurar = despertar (Apagão / Manifestação).
func _fury_input() -> void:
	if _in_just("fury"):
		fury_hold = 0.0
		fury_hold_used = false
	if fury_hold >= 0.0:
		if _in_held("fury"):
			fury_hold += Game.real_dt()
			if fury_hold >= 0.45 and not fury_hold_used:
				fury_hold_used = true
				_try_awaken()
		else:
			if not fury_hold_used:
				_try_ultimate()
			fury_hold = -1.0

func _can_special() -> bool:
	return state in ["idle", "move", "attack", "hit", "dodge"] and ult == null and not Game.cine

func _try_ultimate() -> void:
	if not _can_special():
		return
	if fury < 100.0:
		_say("Fúria insuficiente", Color(1, 0.38, 0.32), 0.8)
		return
	if state == "hit":
		rig.stop_action(0.08)
		set_state("move")
	Ultimate.start(self)

func _try_awaken() -> void:
	if not _can_special():
		return
	if not fk.has_awaken():
		_try_ultimate()
		return
	if fury < 100.0:
		_say("Fúria insuficiente", Color(1, 0.38, 0.32), 0.8)
		return
	if fury_active > 0.0:
		return
	rig.stop_action(0.08)
	set_state("move")
	Ultimate.awaken(self)

func _guard_tick(delta: float) -> void:
	if not was_guard:
		guard_t = 0.0
		rig.play("Sword_Block", {"hold": true, "speed": 2.0, "blend": 0.05})
	guarding = true
	was_guard = true
	guard_t += delta
	combat_t = 2.0
	if lock_target == null:
		var n = Game.nearest_enemy(self, 6.0)
		if n: face_to(n.global_position, delta, 12.0)
	# da defesa dá para esquivar ou atacar direto
	var c := _peek()
	if c == "dodge" or c == "light" or c == "heavy" or c == "chase":
		guarding = false
		was_guard = false
		rig.stop_action(0.06)
		_consume_neutral()

## Golpe em andamento: janelas de combo, cancelamentos e recuperação.
func _attack_tick(delta: float, guard_held: bool) -> void:
	was_guard = false
	var m := cur_move
	var lt: float = m.get("lunge_t", 0.16)
	var lspd := lunge_spd * clampf(lunge_t / maxf(lt, 0.01), 0.0, 1.0) * 1.6 if lunge_t > 0.0 else 0.0
	lunge_t -= delta
	move_dir(forward(), lspd, delta, 30.0)
	var pos := rig.action_pos() - float(m.get("from", 0.0))
	if lock_target and is_instance_valid(lock_target) and pos < float(m.get("combo", 0.2)):
		face_to(lock_target.global_position, delta, 10.0)
	var light: bool = m.get("type", "light") == "light" or m.get("type", "") == "counter"
	var c := _peek()
	# combo: próximo golpe do grafo
	if (c == "light" or c == "heavy") and pos >= float(m.get("combo", 9.0)):
		_pop()
		var nxt: String = m.get("next", {}).get(c, "")
		start_move(nxt if nxt != "" else moves.start[c])
		return
	# cancelamentos: leves a qualquer momento; pesados e finalizadores depois do impacto
	var can_cancel: bool = light or pos >= float(m.get("cancel", 0.0))
	if can_cancel and (c == "dodge" or c == "s0" or c == "s1" or c == "s2" or c == "chase"):
		rig.stop_action(0.05)
		set_state("move")
		_consume_neutral()
		return
	if can_cancel and guard_held:
		set_state("move")
		_guard_tick(delta)
		return
	# recuperação: o direcional interrompe
	if pos >= float(m.get("recover", 9.0)) and wish.length_squared() > 0.04:
		rig.stop_action(0.15)
		set_state("move")
		return
	if pos >= float(m.get("end", 9.0)) or not rig.is_busy():
		rig.stop_action(0.18)
		set_state("move")

func toggle_lock() -> void:
	if lock_target:
		lock_target = null
		Audio.sfx("ui", 0.5)
		return
	var best = null
	var bs := 1e9
	for e in Game.enemies_of(self):
		var d := Game.dist2d(e.global_position, global_position)
		if d > 25.0:
			continue
		var a: float = abs(Game.ang_diff(Game.yaw_to(global_position, e.global_position), Game.cam.yaw))
		var sc: float = a * 6.0 + d * 0.3
		if sc < bs:
			bs = sc; best = e
	lock_target = best
	if best: Audio.sfx("ui", 0.7)

func auto_target(rng := 5.0):
	if lock_target and is_instance_valid(lock_target) and lock_target.alive and Game.dist2d(lock_target.global_position, global_position) < rng + 3.0:
		return lock_target
	var dir_yaw := atan2(wish.x, wish.z) if wish.length_squared() > 0.01 else yaw
	var best = null
	var bs := 1e9
	for e in Game.enemies_of(self):
		var d: float = Game.dist2d(e.global_position, global_position) - e.radius
		if d > rng:
			continue
		var a: float = abs(Game.ang_diff(Game.yaw_to(global_position, e.global_position), dir_yaw))
		if a > 1.6 and d > 1.5:
			continue
		var sc := d + a * 2.0
		if sc < bs:
			bs = sc; best = e
	return best

# ---------------------------------------------------------------------
#  Ataques
# ---------------------------------------------------------------------
func start_move(id: String) -> void:
	if not moves.has(id):
		return
	if exhausted > 0.0 and stamina < 5.0:
		return
	var m: Dictionary = moves[id]
	cur_move = m
	cur_move_id = id
	counter_t = 0.0
	set_state("attack")
	combat_t = 4.0
	var tgt = auto_target(12.0 if fury_active > 0.0 else 6.0)
	if tgt and fury_active > 0.0 and Game.dist2d(tgt.global_position, global_position) > 3.4:
		blink_to(tgt)
	lunge_t = 0.0
	lunge_spd = 0.0
	var lt: float = m.get("lunge_t", 0.16)
	if tgt:
		snap_face(tgt.global_position)
		var d: float = Game.dist2d(tgt.global_position, global_position) - tgt.radius - 0.9
		if d > 0.15:
			lunge_t = lt
			lunge_spd = minf(float(m.get("lunge", 5.0)) * 1.6, d / lt)
	else:
		if wish.length_squared() > 0.01:
			snap_face(atan2(wish.x, wish.z))
		lunge_t = lt
		lunge_spd = float(m.get("lunge", 5.0)) * 0.45
	if m.has("jump") and is_on_floor():
		vy = m.jump
	fk.on_attack_start(m)
	var spd: float = m.speed * (1.3 if fury_active > 0.0 else 1.0) * (0.75 if exhausted > 0.0 else 1.0) * fk.anim_mul()
	var from: float = m.get("from", 0.0)
	var ev := {}
	for i in m.hits.size():
		ev[from + float(m.hits[i].t)] = "hit%d" % i
	var mv := m
	rig.play(m.anim, {"speed": spd, "blend": 0.07, "from": from, "events": ev, "on_event": func(e: String):
		if cur_move == mv and state == "attack":
			melee_hit(mv, mv.hits[int(e.substr(3))])})
	var heavy: bool = m.type != "light"
	Game.fx.trail(rig, fk.trail_col(m), minf(0.45, float(m.get("end", 0.5)) / spd * 0.8), fk.trail_bone(m))
	Audio.sfx("swingHeavy" if heavy else "swing", 1.0, 1.12 if m.type == "light" else 1.0)
	stamina = max(0.0, stamina - (7.0 if heavy else 3.0))
	stamina_delay = 0.4

## Compatibilidade (roteiro/harness): golpe leve a partir do neutro.
func start_attack() -> void:
	start_move(moves.start.light)

func melee_hit(m: Dictionary, h: Dictionary) -> void:
	if h.get("proj", false):
		# golpe à distância (arco, adagas de arremesso…): o kit dispara
		fk.fire_hit(m, h)
		return
	var pos := global_position
	var feel: Dictionary = MoveSet.FEEL.get(m.type, MoveSet.FEEL.light)
	var heavy: bool = m.type != "light"
	var ice: bool = m.get("ice", false)
	var sp := pos + Vector3(0, 1.1, 0) + forward() * 0.2
	var col: Color = fk.hit_col(m)
	if h.has("slash"):
		Game.fx.slash(sp, yaw, h.slash.merged({"color": col, "dark": fury_active > 0.0, "intensity": 3.0 if fury_active > 0.0 or heavy else 2.2}))
	if ice:
		var ip := pos + Vector3(0, 1.3, 0) + forward() * 1.2
		Game.fx.burst("ice", ip, {"n": 22 if heavy else 10})
		Game.fx.sphere(ip, {"color": Color(0.62, 0.88, 1.0), "r1": 1.2 if heavy else 0.6, "life": 0.2, "opacity": 0.18})
		Audio.sfx("ice", 0.6)
	if int(h.get("spikes", 0)) > 0:
		var y0 := yaw
		for k in int(h.spikes):
			Game.after(k * 0.035, func():
				var p := pos + Game.fwd(y0) * (1.2 + k * 0.75)
				Game.fx.ice_spike(p, {"h": randf_range(1.0, 2.2), "r": 0.22, "life": 1.6, "silent": k > 0}))
	if h.get("area", false):
		Game.fx.shockwave(pos + forward() * 0.8, col, float(h.range), {"glow": col if h.get("finisher", false) else Color.BLACK})
	fk.melee_fx(m, h, pos)
	var hits := 0
	for e in Game.enemies_of(self):
		var d := Game.dist2d(e.global_position, pos)
		if d > h.range + e.radius:
			continue
		if abs(Game.ang_diff(Game.yaw_to(pos, e.global_position), yaw)) > h.arc / 2.0 and d > e.radius + 0.6:
			continue
		var crit := randf() < (0.35 if fury_active > 0.0 else (0.2 if m.type == "counter" else 0.1))
		var multi: bool = m.hits.size() > 1 and not h.get("finisher", false)
		var o := {"heavy": heavy, "knock": h.get("knock", 3.0), "launch": h.get("launch", 0.0), "reaction": h.get("reaction", "flinch"),
			"crit": crit, "element": "ice" if ice else String(h.get("element", "")), "hitstop": feel.hitstop * (0.6 if multi else 1.0),
			"shake": feel.shake, "move_type": m.type, "finisher": h.get("finisher", false),
			"spark": Color(1, 0.95, 0.75), "spark2": Color(1, 0.42, 0.06)}
		o = fk.modify_hit(e, o, m, h)
		var hp0: float = e.hp
		if Game.damage(self, e, h.dmg * dmg_mul(), o):
			fk.on_hit_dealt(e, hp0 - e.hp, o)
		hits += 1
	if hits > 0:
		Game.cam.kick(feel.kick)
		if feel.impact > 0.0 and Game.post:
			Game.post.impact = maxf(Game.post.impact, feel.impact)
		if h.get("finisher", false):
			if Game.post: Game.post.impact_frames(0.05)
			if feel.slow > 0.0:
				Game.slow(feel.slow, 0.3)
			Game.fx.flash(pos + Vector3(0, 1.4, 0) + forward() * 1.2, col, 10.0, 0.25, 10.0)
			Audio.sfx("hitHeavy", 0.8)
			Ultimate.finisher_cut(self)

func dodge() -> void:
	if stamina < 18.0:
		_say("Sem fôlego", Color(0.75, 0.75, 0.75), 0.8)
		return
	stamina -= 22.0
	stamina_delay = 0.6
	dodge_dir = wish.normalized() if wish.length_squared() > 0.01 else -forward()
	dodge_t = 0.0
	perfect_used = false
	iframes = 0.36
	snap_face(atan2(dodge_dir.x, dodge_dir.z))
	set_state("dodge")
	counter_t = 0.55
	fk.dodge_fx()
	rig.play("Roll", {"speed": 2.0, "blend": 0.04})
	Audio.sfx("dodge")
	Game.cam.kick(3.0)
	Game.fx.burst("dust", global_position, {"n": 6, "size": 0.6})

func use_potion() -> void:
	if potions <= 0 or hp >= max_hp or heal_t > 0.0:
		_say("Sem poções" if potions <= 0 else "Vida cheia", Color(0.75, 0.75, 0.75), 0.8)
		return
	potions -= 1
	heal_t = 1.6
	Audio.sfx("potion")
	Game.fx.burst("heal", global_position, {"n": 25})

func blink_to(tgt) -> void:
	Game.fx.afterimage(self, Color(1, 0.15, 0.3) if fury_active > 0.0 else Color(0.55, 0.3, 1.0), 0.45)
	var behind: Vector3 = tgt.global_position - Game.fwd(tgt.yaw) * (tgt.radius + 0.9)
	Game.fx.burst("shadow", global_position + Vector3(0, 1, 0), {"n": 18, "r": 0.4, "speed": 2.0})
	Game.fx.burst("magic", global_position + Vector3(0, 1, 0), {"n": 10, "color": Color(1, 0.12, 0.25), "color2": Color(0.2, 0, 0.06)})
	if Game.level and Game.level.has_method("clamp_point"):
		behind = Game.level.clamp_point(behind, radius)
	global_position = Vector3(behind.x, global_position.y, behind.z)
	snap_face(tgt.global_position)
	Game.fx.burst("shadow", global_position + Vector3(0, 1, 0), {"n": 18, "r": 0.4, "speed": 2.0})
	Audio.sfx("blink")
	Game.cam.shake(0.15)

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int) -> void:
	var sk: Dictionary = skills[i]
	if cd[i] > 0.0:
		_say("Recarregando", Color(0.63, 0.63, 0.63), 0.6)
		return
	if energy < sk.cost:
		_say("Energia insuficiente", Color(0.5, 0.75, 1.0), 0.8)
		return
	var tgt = auto_target(14.0 if i == 2 else 16.0)
	if sk.get("ai", {}).get("need_target", false) and tgt == null:
		_say("Nenhum alvo", Color(0.63, 0.63, 0.63), 0.6)
		return
	energy -= sk.cost
	cd[i] = sk.cd
	combat_t = 4.0
	if tgt:
		snap_face(tgt.global_position)
	if Game.ui and brain == null: Game.ui.skill_flash(i)
	fk.use_skill(i, tgt)

func ukulele_front(on: bool) -> void:
	if rig.ukulele == null:
		return
	var bi := rig.skel.find_bone("spine_03")
	var rest := rig.skel.get_bone_global_rest(bi).affine_inverse()
	rig.ukulele.transform = rest * (rig.ukulele_front if on else rig.ukulele_back)
	if on:
		rig.pose.set_offset("upperarm_l", Vector3(0, 0, -55), 1.0)
		rig.pose.set_offset("lowerarm_l", Vector3(0, -70, 0), 1.0)
		rig.pose.set_offset("upperarm_r", Vector3(0, 0, 40), 1.0)
		rig.pose.set_offset("lowerarm_r", Vector3(0, 60, 0), 1.0)
	else:
		rig.pose.clear_all()

func _crescent(start: Vector3, dir: Vector3, tgt, dmg: float, col1: Color, col2: Color, homing := 3.0, scale := 1.1) -> void:
	Game.spawn_projectile({"kind": "crescent", "pos": start, "vel": dir * 20.0, "team": team, "dmg": dmg, "radius": 0.7, "life": 1.4, "src": self, "pierce": true,
		"color": col1, "color2": col2, "scale": scale, "knock": 4.0, "target": tgt, "homing": homing if tgt else 0.0, "fury_gain": 2.0,
		"trail": func(p, _dt):
			if randf() < 0.8: Game.fx.burst("magic", p.pos, {"n": 1, "speed": 0.4, "size": 0.8, "color": col1, "color2": col2})
			if randf() < 0.18: Game.fx.emit("note", p.pos, Vector3(0, 0.8, 0), 0.8, 0.32, col2),
		"on_hit": func(_p, t, _ok): resonate(t)})

func _kiana_skill(i: int, tgt) -> void:
	match i:
		0:
			set_state("cast"); cast_dur = 0.45; cast_move = 0.0
			rig.play("Spell_Simple_Shoot", {"speed": 1.3, "events": {0.18: "hit"}, "on_event": func(_e):
				var start := global_position + Vector3(0, 1.15, 0) + forward() * 0.6
				var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt else forward()
				Audio.sfx("soundBlade")
				var step := 1 if fury_active > 0.0 else 2
				for k in range(-1, 2, step):
					_crescent(start, dir.rotated(Vector3.UP, k * 0.12), tgt, 22.0 * dmg_mul(), Color(0.7, 0.45, 1.0), Color(0.38, 0.92, 1.0))})
		1:
			set_state("cast"); cast_dur = 0.8; cast_move = 0.0; iframes = 0.45
			ukulele_front(true)
			rig.play("Spell_Simple_Shoot", {"speed": 0.75, "events": {0.32: "hit"}, "on_event": func(_e):
				Audio.sfx("shock")
				Game.cam.shake(0.45); Game.cam.kick(6.0)
				var c := global_position
				Game.fx.shockwave(c, Color(1, 0.82, 0.48), 6.5, {"glow": Color(1.0, 0.75, 0.3)})
				Game.fx.ring(c, {"color": Color(0.38, 0.92, 1.0), "r1": 5.0, "life": 0.4})
				Game.fx.burst("note", c + Vector3(0, 1.2, 0), {"n": 1})
				for k in 10:
					Game.fx.emit("note", c + Vector3(0, 1.0, 0), Vector3(cos(k * 0.63), 0.6, sin(k * 0.63)) * 4.0, 1.0, 0.45, Color(1, 0.86, 0.5) if k % 2 else Color(0.5, 0.95, 1.0))
				Game.fx.sphere(c + Vector3(0, 1, 0), {"color": Color(1, 0.85, 0.63), "r1": 3.0, "life": 0.25, "opacity": 0.14})
				Game.fx.burst("gold", c + Vector3(0, 0.5, 0), {"n": 40, "r": 2.0})
				Game.fx.flash(c + Vector3(0, 1.5, 0), Color(1, 0.82, 0.5), 14.0, 0.35, 12.0)
				Game.area_attack({"pos": c, "radius": 6.0, "dmg": 30.0 * dmg_mul(), "team": team, "src": self, "delay": 0.0, "knock": 14.0, "heavy": true, "telegraph": false, "fury_gain": 3.0})
				for e in Game.enemies_of(self):
					if Game.dist2d(e.global_position, c) < 6.5:
						e.stun(1.2); resonate(e)
				Game.after(0.45, func(): ukulele_front(false))})
		2:
			blink_to(tgt)
			var m := {"anim": "Sword_Dash", "from": 0.18, "speed": 1.6, "type": "heavy", "lunge": 6.0, "lunge_t": 0.12,
				"hits": [{"t": 0.24, "dmg": 38.0, "range": 2.8, "arc": 1.7, "knock": 7.0, "reaction": "knockback", "slash": {"roll": 1.5, "big": true}}],
				"combo": 0.32, "cancel": 0.28, "recover": 0.5, "end": 0.75, "next": {"light": "L3", "heavy": "L3H"}}
			cur_move = m
			cur_move_id = "SKILL"
			set_state("attack")
			lunge_t = 0.12; lunge_spd = 6.0
			rig.play("Sword_Dash", {"speed": 1.6, "from": 0.18, "events": {0.42: "hit"}, "on_event": func(_e):
				if is_instance_valid(tgt):
					Game.fx.burst("magic", tgt.chest_pos(), {"n": 20, "color": Color(1, 0.2, 0.3), "color2": Color(0.15, 0, 0.06)})
				melee_hit(m, m.hits[0])})

func resonate(t) -> void:
	if t and is_instance_valid(t):
		t.resonance = min(99, t.resonance + 1)

# ---------------------------------------------------------------------
#  Fúria
# ---------------------------------------------------------------------
func activate_fury() -> void:
	if fury < 100.0:
		_say("Fúria insuficiente", Color(1, 0.38, 0.32), 0.8)
		return
	fk.awaken()

## Liga o estado de despertar por `dur` segundos (o kit cuida dos efeitos).
func begin_awaken(dur: float) -> void:
	fury_active = dur
	fury = 100.0
	awakened = true
	set_meta("awaken_dur", dur)

## Apagão de Kiana (chamado pelo kit dela).
func apagao_start() -> void:
	begin_awaken(9.0)
	fury = 100.0
	Game.flags["apagao"] = true
	Audio.sfx("fury")
	Game.cam.shake(0.6); Game.cam.kick(10.0)
	Game.slow(0.5, 0.2)
	Game.fx.burst("shadow", global_position + Vector3(0, 1, 0), {"n": 40, "r": 0.6, "speed": 3.0, "size": 1.4})
	Game.fx.shockwave(global_position, Color(1, 0.06, 0.12), 6.0, {"glow": Color(1.0, 0.05, 0.1), "debris": true})
	Game.fx.aura_end(aura_node)
	aura_node = Game.fx.aura(self, Color(0.9, 0.02, 0.08), Color(0.08, 0.0, 0.02), 1.8)
	rig.set_eye_glow(Color(3.0, 0.05, 0.02))
	rig.set_face(true)
	_say("— APAGÃO —", Color(1, 0.12, 0.12), 1.6, true)

func _update_fury(delta: float) -> void:
	fury_active -= delta
	fury = max(0.0, fury_active / float(get_meta("awaken_dur", 9.0)) * 100.0)
	fk.awaken_tick(delta)
	if fury_active <= 0.0:
		end_fury()

func end_fury() -> void:
	if fury_active <= 0.0 and not awakened and not Game.flags.get("apagao", false):
		return
	fury_active = 0.0
	awakened = false
	fury = 0.0
	Game.fx.aura_end(aura_node)
	aura_node = null
	fk.awaken_end()

func start_ult() -> void:
	fury = 0.0
	ult = {"t": 0.0, "beat": 0.0, "n": 0}
	set_state("cast"); cast_dur = 999.0
	ukulele_front(true)
	rig.play("Spell_Simple_Idle", {"loop": true, "blend": 0.2})
	dmg_taken_mul = 0.3
	Audio.set_layer("harmonic", true)
	Audio.sfx("reveal")
	Game.cam.shake(0.4)
	_say("MANIFESTAÇÃO HARMÔNICA", Color(1, 0.88, 0.55), 2.0, true)
	Game.fx.shockwave(global_position, Color(0.38, 0.95, 1.0), 8.0, {"glow": Color(0.4, 0.9, 1.0), "debris": false})
	Game.fx.aura_end(aura_node)
	aura_node = Game.fx.aura(self, Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.45), 2.0)
	if Game.post: Game.post.harmonic = 1.0

func _update_ult(delta: float) -> void:
	ult.t += delta
	ult.beat -= delta
	if randf() < 0.9:
		Game.fx.burst("magic", global_position + Vector3(randf_range(-2, 2), randf_range(0.5, 2.5), randf_range(-2, 2)), {"n": 1, "color": Color(0.38, 0.95, 1.0) if randf() < 0.5 else Color(1, 0.82, 0.44), "color2": Color(1, 1, 1), "speed": 0.6})
	if randf() < 0.12:
		Game.fx.emit("note", global_position + Vector3(randf_range(-1.2, 1.2), randf_range(0.6, 2.2), randf_range(-1.2, 1.2)), Vector3(0, 1.2, 0), 1.4, 0.4, Color(1, 0.86, 0.5) if randf() < 0.5 else Color(0.5, 0.95, 1.0))
	var tg = lock_target if lock_target else Game.nearest_enemy(self, 30.0)
	if tg:
		face_to(tg.global_position, delta, 4.0)
	if ult.beat <= 0.0:
		ult.beat = 0.42
		ult.n += 1
		Audio.chord(ult.n % 4)
		var start := global_position + Vector3(0, 1.2, 0)
		for e in Game.enemies_of(self):
			if Game.dist2d(e.global_position, global_position) > 30.0:
				continue
			var dir: Vector3 = (e.chest_pos() - start).normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
			var c1 := Color(0.38, 0.95, 1.0) if ult.n % 2 == 1 else Color(1, 0.82, 0.44)
			Game.spawn_projectile({"kind": "crescent", "pos": start + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)), "vel": dir * 16.0, "team": team, "dmg": 16.0, "radius": 0.8, "life": 2.0, "src": self,
				"color": c1, "color2": Color(1, 1, 1), "target": e, "homing": 6.0, "scale": 1.2, "fury_gain": 0.0,
				"trail": func(p, _dt): if randf() < 0.7: Game.fx.burst("magic", p.pos, {"n": 1, "color": Color(0.5, 0.97, 1.0), "color2": Color(1, 0.88, 0.56), "speed": 0.3}),
				"on_hit": func(_p, t, _ok): resonate(t)})
		if ult.n % 3 == 0:
			Game.fx.ring(global_position, {"color": Color(1, 0.82, 0.48), "r1": 7.0, "life": 0.5, "intensity": 3.0})
			Game.area_attack({"pos": global_position, "radius": 7.0, "dmg": 20.0, "team": team, "src": self, "delay": 0.0, "knock": 10.0, "telegraph": false, "fury_gain": 0.0})
			Game.cam.shake(0.25)
	if ult.t >= 7.5:
		end_ult()

func end_ult() -> void:
	ult = null
	Game.fx.aura_end(aura_node)
	aura_node = null
	dmg_taken_mul = Game.difficulty
	rig.stop_action(0.2)
	ukulele_front(false)
	set_state("move")
	Audio.set_layer("harmonic", false)
	energy = 0.0
	stamina = 0.0
	exhausted = 4.0
	if Game.post: Game.post.harmonic = 0.0
	_say("Exausta... reflexos lentos", Color(0.63, 0.63, 0.75), 1.6)
	Game.emit_ev("ultEnd")

func punho_flamejante() -> void:
	var tgt = auto_target(8.0)
	if tgt == null:
		tgt = Game.nearest_enemy(self, 8.0)
	fury = 0.0
	set_state("cast"); cast_dur = 1.2; cast_move = 0.0; iframes = 1.3
	if tgt:
		snap_face(tgt.global_position)
	Game.slow(0.8, 0.25)
	Game.cam.kick(12.0)
	_say("PUNHO FLAMEJANTE!", Color(1, 0.94, 0.7), 1.6, true)
	Audio.sfx("fury")
	var fist := rig.attach_model(Game.fx.glow_ball(Color(4.0, 3.6, 2.4), 0.16), "hand_r", Transform3D(Basis(), rig.skel.get_bone_global_rest(rig.skel.find_bone("hand_r")).origin))
	rig.play("Melee_Hook", {"speed": 0.6, "events": {0.22: "hit"}, "on_event": func(_e):
		if is_instance_valid(fist): fist.queue_free()
		var c := global_position + forward() * 1.6
		Audio.sfx("explosion"); Audio.sfx("fire")
		Game.cam.shake(1.0)
		if Game.post: Game.post.flash = 0.4
		Game.fx.sphere(c + Vector3(0, 1.4, 0), {"color": Color(1, 0.8, 0.5), "r1": 2.6, "life": 0.45, "intensity": 2.0, "opacity": 0.3})
		Game.fx.shockwave(c, Color(1, 0.7, 0.3), 9.0, {"glow": Color(1.0, 0.55, 0.15), "life": 0.7})
		Game.fx.impact(c + Vector3(0, 1.4, 0), Color(1, 0.8, 0.4), 4.0)
		Game.fx.burst("fire", c, {"n": 80, "r": 1.5, "color": Color(1, 1, 1), "color2": Color(1, 0.7, 0.12), "size": 1.6, "up": 2.0})
		Game.fx.burst("spark", c + Vector3(0, 1.4, 0), {"n": 60, "color": Color(1, 1, 1), "color2": Color(1, 0.75, 0.25)})
		Game.fx.flash(c + Vector3(0, 2, 0), Color(1, 0.94, 0.75), 30.0, 0.8, 25.0)
		if tgt and is_instance_valid(tgt):
			tgt.set("armor_broken", 12.0)
		Game.area_attack({"pos": c, "radius": 4.5, "dmg": 240.0 * (1.45 if versus else 1.0), "team": team, "src": self, "delay": 0.0, "knock": 18.0, "telegraph": false, "element": "fire", "unblockable": true, "heavy": true, "fury_gain": 0.0})
		Game.emit_ev("punho", tgt)})

# =====================================================================
#  Modo Versus (estilo Storm): reações, Substituição, investida e carga de chakra
# =====================================================================
var charge_aura = null

func setup_versus(opp, hp_max: float) -> void:
	versus = true
	opponent = opp
	max_hp = hp_max
	hp = hp_max
	potions = 0
	energy = max_energy
	dmg_taken_mul = 1.0
	rig.combat = true

func chakra_col() -> Color:
	return K.get("chakra", Color(0.6, 0.5, 1.0))

## Volta ao estado inicial entre rounds (revive se preciso). A fúria é mantida.
func versus_reset(pos: Vector3, face: float) -> void:
	if ult != null:
		ult = null
		Audio.set_layer("harmonic", false)
	end_fury()
	Game.fx.aura_end(aura_node)
	aura_node = null
	_end_charge(false)
	fk.reset()
	untargetable = false
	freeze_immune = false
	st_slow = 0.0; st_root = 0.0; st_blind = 0.0; frost = 0.0
	break_freeze()
	rig.visible = true
	alive = true
	dead = false
	collision_layer = 2
	collision_mask = 1 | 2
	hp = max_hp
	energy = max_energy
	stamina = max_stamina
	exhausted = 0.0
	subs = 4.0
	cd = [0.0, 0.0, 0.0]
	queue.clear()
	cur_move = {}
	counter_t = 0.0
	chase_window = 0.0
	iframes = 0.0
	invulnerable = false
	scripted = false
	guarding = false
	was_guard = false
	combo_hits = 0
	dmg_taken_mul = 1.0
	move_vel = Vector3.ZERO
	knock = Vector3.ZERO
	vy = 0.0
	teleport(pos)
	snap_face(face)
	rig.stop_action(0.0)
	rig.set_face(false)
	rig.set_eye_glow(Color(1.4, 0.1, 0.05) if kit == "kiana" else Color.BLACK)
	ukulele_front(false)
	set_state("idle")

func _versus_tick(delta: float) -> void:
	subs = minf(4.0, subs + delta * 0.11)
	chase_window -= delta
	if opponent and is_instance_valid(opponent) and opponent.alive and not opponent.untargetable and st_blind <= 0.0:
		lock_target = opponent
	elif st_blind > 0.0 or (opponent and is_instance_valid(opponent) and opponent.untargetable):
		lock_target = null
	if st_blind > 0.0 and brain == null and Game.post:
		Game.post.vig = maxf(Game.post.vig, 1.2)

## Reação a golpes no Versus: atordoamento acumulado por combo, lançamento e arremesso.
func on_freeze(t: float) -> void:
	_end_charge(false)
	cur_move = {}
	queue.clear()
	set_state("hit")
	state_lock = t
	rig.set_action_speed(0.0)

func on_unfreeze() -> void:
	rig.set_action_speed(1.0)
	if state == "hit":
		state_lock = minf(state_lock, state_t + 0.1)

func _versus_react(_src, amount: float, o: Dictionary) -> void:
	if ult != null or state == "cine" or state == "ult" or state == "dodge":
		return
	if st_freeze > 0.0 or fk.super_armor():
		return
	if not o.get("fx", true) or guarding:
		return
	_end_charge(false)
	var r: String = o.get("reaction", "knockback" if o.get("heavy", false) and amount > 20.0 else "flinch")
	var dur := 0.36
	match r:
		"launch":
			dur = 1.0
			rig.play("Hit_Knockback", {"speed": 0.9, "blend": 0.05})
		"knockback":
			dur = 0.8
			rig.play("Hit_Knockback", {"speed": 1.1, "blend": 0.05})
		"stagger":
			dur = 0.52
			rig.play("Hit_Head", {"speed": 1.0, "blend": 0.05})
		_:
			rig.play("Hit_Chest" if randf() < 0.5 else "Hit_Head", {"speed": 1.4, "blend": 0.04})
	var left := maxf(0.0, state_lock - state_t) if state == "hit" else 0.0
	combo_hits = combo_hits + 1 if state == "hit" else 1
	set_state("hit")
	state_lock = maxf(dur, minf(left + 0.14, 1.3))
	cur_move = {}
	# mantém só o pedido de Substituição apertado durante o golpe
	var keep := []
	for q in queue:
		if q.c == "dodge":
			keep.append(q)
	queue = keep
	Audio.sfx("hurt", 0.7)

## Substituição: troca de lugar com um tronco e reaparece atrás do atacante.
func substitute() -> void:
	subs -= 1.0
	var old := global_position
	Game.fx.sub_log(old, yaw)
	Game.fx.burst("smoke", old + Vector3(0, 1.0, 0), {"n": 22, "r": 0.5, "speed": 2.2, "size": 1.3})
	var src = last_hit_by
	var dest: Vector3 = old - forward() * 3.0
	if src and is_instance_valid(src):
		dest = src.global_position - Game.fwd(src.yaw) * 1.7
	if Game.level and Game.level.has_method("clamp_point"):
		dest = Game.level.clamp_point(dest, radius)
	teleport(Vector3(dest.x, old.y, dest.z))
	vy = 0.0
	knock = Vector3.ZERO
	move_vel = Vector3.ZERO
	Game.fx.burst("smoke", global_position + Vector3(0, 1.0, 0), {"n": 14, "r": 0.4, "speed": 1.6})
	Game.fx.afterimage(self, chakra_col(), 0.3)
	if src and is_instance_valid(src):
		snap_face(src.global_position)
	rig.stop_action(0.05)
	set_state("move")
	iframes = 0.45
	counter_t = 0.6
	combo_hits = 0
	Audio.sfx("blink")
	Audio.sfx("dodge", 0.6)
	Game.cam.shake(0.15)
	if Game.ui:
		Game.ui.toast("SUBSTITUIÇÃO!" if brain == null else "SUBSTITUIÇÃO — CPU", chakra_col(), 0.9)

## Investida de chakra: avança rápido até o oponente (Shift no Versus).
func chakra_dash() -> void:
	var t = opponent if opponent and is_instance_valid(opponent) and opponent.alive else auto_target(30.0)
	if t == null:
		return
	if energy < 10.0:
		_say("Chakra insuficiente", Color(0.5, 0.75, 1.0), 0.8)
		return
	energy -= 10.0
	set_state("chase")
	chase_t = 0.0
	rig.stop_action(0.06)
	snap_face(t.global_position)
	Game.fx.afterimage(self, chakra_col(), 0.3)
	Game.fx.burst("dust", global_position, {"n": 8, "size": 0.7})
	Audio.sfx("dodge")
	Audio.sfx("whoosh", 0.5)
	if brain == null:
		Game.cam.kick(6.0)
		if Game.post: Game.post.speed_target = 0.45

func _chase_tick(delta: float) -> void:
	chase_t += delta
	var t = opponent
	var done: bool = t == null or not is_instance_valid(t) or not t.alive or chase_t > 0.6
	if not done:
		var to: Vector3 = t.global_position - global_position
		to.y = 0
		var d := to.length()
		move_dir(to.normalized(), 17.0, delta, 30.0)
		face_to(t.global_position, delta, 20.0)
		if randf() < 0.7:
			Game.fx.burst("magic", global_position + Vector3(0, randf_range(0.3, 1.4), 0), {"n": 1, "color": chakra_col(), "speed": 0.4})
		if d < 1.9 or (_peek() == "light" and d < 4.0) or _peek() == "heavy":
			done = true
	if done:
		set_state("move")
		chase_window = 0.35
		if brain == null and Game.post:
			Game.post.speed_target = 0.0
		_consume_neutral()

func _start_charge() -> void:
	if energy >= max_energy - 0.5 or (state != "move" and state != "idle"):
		return
	set_state("charge")
	charging = true
	rig.play("Spell_Simple_Idle", {"loop": true, "blend": 0.15})
	charge_aura = Game.fx.aura(self, chakra_col(), chakra_col().lerp(Color.WHITE, 0.35), 0.7)
	Audio.sfx("magic", 0.4)

func _charge_tick(delta: float, held: bool) -> void:
	energy = minf(max_energy, energy + delta * 40.0)
	if randf() < 0.5:
		var a := randf() * TAU
		Game.fx.emit("magic", global_position + Vector3(cos(a) * 0.6, randf_range(0.0, 0.4), sin(a) * 0.6), Vector3(0, randf_range(2.0, 3.5), 0), 0.6, 0.2, chakra_col())
	if not held or energy >= max_energy or _peek() != "":
		_end_charge(true)
		_consume_neutral()

func _end_charge(to_move: bool) -> void:
	if not charging:
		return
	charging = false
	Game.fx.aura_end(charge_aura)
	charge_aura = null
	if state == "charge":
		rig.stop_action(0.15)
		if to_move:
			set_state("move")

## Atordoamento (aparo, Ressonância…). Só tem efeito entre lutadores no Versus.
func stun(t: float) -> void:
	if not versus or not alive or ult != null or st_freeze > 0.0 or fk.super_armor():
		return
	_end_charge(false)
	cur_move = {}
	queue.clear()
	rig.play("Hit_Knockback", {"speed": 0.9, "blend": 0.05})
	set_state("hit")
	state_lock = maxf(state_lock - state_t, t * 0.6)
