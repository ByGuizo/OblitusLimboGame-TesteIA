extends FighterKit
## Viktor Vanshee — o Pilar do Gelo, Herança Celestial (o mais forte da obra).
##  Passiva  Aura Glacial: o chão trinca de gelo e quem está perto fica lento e acumula Frio.
##  Congelamento: golpes de gelo acumulam Frio; em 100 o alvo vira um bloco de gelo.
##                Um golpe pesado num alvo congelado ESTILHAÇA (dano altíssimo).
##  Força contida: superarmadura nos golpes pesados e finalizadores.
##  Habilidades: Estaca Cristalina (empala e prende) · Floresta de Lanças (lança para o alto) ·
##               Gelo Negro (agarrão: o gelo sobe pelo braço até o osso estalar).
##  Despertar  Domínio do Inverno: o salão congela, o oponente fica em câmera lenta.
##  Ultimate   Punho Flamejante: o mundo congela, floresta de lanças, o gelo negro no pescoço
##             e o sol na mão do Mestre do Gelo.

const ICE := Color(0.62, 0.88, 1.0)
var _aura_t := 0.0
var _frost_t := 0.0

func stats() -> Dictionary:
	return {"hp": 160.0, "speed": 5.0, "sprint": 7.5, "color": ICE, "chakra": Color(0.45, 0.8, 1.0),
		"name": "Viktor Vanshee", "title": "O Pilar do Gelo", "vs_hp": 500.0, "fury_gain": 1.4}

func moves() -> Dictionary:
	return MoveSet.VIKTOR

func skills() -> Array:
	return [
		{"name": "Estaca Cristalina", "cost": 15.0, "cd": 1.3, "icon": "stake", "ai": {"kind": "ranged", "range": 18.0}},
		{"name": "Floresta de Lanças", "cost": 35.0, "cd": 6.0, "icon": "forest", "ai": {"kind": "aoe", "range": 10.0}},
		{"name": "Gelo Negro", "cost": 25.0, "cd": 5.0, "icon": "blackice", "ai": {"kind": "grab", "range": 3.5}}]

func awaken_name() -> String:
	return "DOMÍNIO DO INVERNO"

func ult_info() -> Dictionary:
	return {"name": "PUNHO FLAMEJANTE", "col": Color(1.0, 0.6, 0.2), "rush": "Shield_Dash", "icon": "punch"}

func win_anim() -> String:
	return "Idle_Shield_Break"

func dmg_mul() -> float:
	return 1.25 if P.awakened else 1.0

func trail_col(_m: Dictionary) -> Color:
	return Color(0.75, 0.95, 1.0) if not P.awakened else Color(0.9, 0.98, 1.0)

func trail_bone(m: Dictionary) -> String:
	return "hand_l" if m.get("anim", "") == "Punch_Jab" else "hand_r"

func super_armor() -> bool:
	if P.awakened:
		return true
	return P.state == "attack" and String(P.cur_move.get("type", "")) in ["heavy", "finisher"]

func dodge_fx() -> void:
	Game.fx.afterimage(P, Color(0.5, 0.85, 1.0))
	Game.fx.burst("ice", P.global_position + Vector3(0, 0.6, 0), {"n": 8, "r": 0.3})

# ---------------------------------------------------------------------
#  Passiva: Aura Glacial
# ---------------------------------------------------------------------
func tick(delta: float) -> void:
	if randf() < (0.3 if P.awakened else 0.12):
		for b in ["hand_l", "hand_r"]:
			Game.fx.burst("ice", P.rig.bone_world(b), {"n": 1, "speed": 0.3})
	var fighting: bool = P.combat_t > 0.0 or P.versus or Game.in_combat
	if not fighting or not P.alive:
		return
	_aura_t -= delta
	if _aura_t <= 0.0:
		_aura_t = 0.5
		var r := 12.0 if P.awakened else 4.5
		for e in foes_in(r):
			e.apply_status("slow", 0.7, 0.55 if P.awakened else 0.75)
			e.add_frost(8.0 if P.awakened else 3.0)
	# o chão trinca de gelo por onde ele passa
	_frost_t -= delta
	if _frost_t <= 0.0:
		_frost_t = 0.6 if P.awakened else 1.4
		var off := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)) if P.awakened else Vector3.ZERO
		Game.fx.cracks(P.global_position + off, 1.6 if P.awakened else 1.1, Color(0.4, 0.8, 1.0), 3.5)

# ---------------------------------------------------------------------
#  Congelamento e Estilhaçar
# ---------------------------------------------------------------------
func modify_hit(target, o: Dictionary, m: Dictionary, _h: Dictionary) -> Dictionary:
	o["spark"] = Color(0.9, 0.98, 1.0)
	o["spark2"] = Color(0.3, 0.65, 1.0)
	if target.st_freeze > 0.0 and String(m.get("type", "light")) != "light":
		o["dmg_mul"] = 1.8
		o["crit"] = true
		o["shatter"] = true
		o["reaction"] = "knockback"
		o["knock"] = maxf(float(o.get("knock", 3.0)), 10.0)
	return o

func on_hit_dealt(target, _amount: float, o: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	if o.get("shatter", false):
		target.break_freeze()
		if Game.ui:
			Game.ui.toast("ESTILHAÇAR!", Color(0.7, 0.92, 1.0), 0.9, true)
		if Game.post:
			Game.post.impact_frames(0.05, Color(0.85, 0.95, 1.0))
		Game.cam.shake(0.5)
		return
	var v := 16.0
	match String(o.get("move_type", "light")):
		"heavy", "dash", "counter": v = 26.0
		"finisher": v = 40.0
	if P.awakened:
		v *= 2.2
	if target.get("boss"):
		v *= 0.4
	target.add_frost(v, 1.3 if not target.get("boss") else 0.6)

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _stake(tgt)
		1: _forest(tgt)
		2: _black_ice(tgt)

## Estaca Cristalina — a mesma que empalou Gyotto: rápida, empala e prende o alvo.
func _stake(tgt) -> void:
	cast(0.42, "Spell_Simple_Shoot", 1.35)
	at(0.13, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.3, 0) + P.forward() * 0.8
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("ice")
		Audio.sfx("whoosh", 0.5)
		proj({"kind": "spear", "pos": start, "vel": dir * 32.0, "dmg": 26.0 * P.dmg_mul(), "radius": 0.55, "life": 1.0, "element": "ice", "scale": 1.35, "knock": 3.0, "heavy": true,
			"trail": func(p, _dt):
				Game.fx.burst("ice", p.pos, {"n": 1, "speed": 0.3})
				if randf() < 0.4: Game.fx.emit("magic", p.pos, Vector3.ZERO, 0.3, 0.3, Color(0.6, 0.9, 1.0)),
			"on_hit": func(_p, t, ok):
				if not ok or not is_instance_valid(t): return
				t.add_frost(45.0)
				t.apply_status("root", 0.9)
				Game.fx.ice_spike(t.global_position, {"h": 1.6, "r": 0.2, "life": 1.2, "silent": true})
				Game.fx.burst("ice", t.chest_pos(), {"n": 18}),
			"on_expire": func(p): Game.fx.burst("ice", p.pos, {"n": 10})}))

## Floresta de Lanças — empala e lança o alvo para o alto (abre combo aéreo).
func _forest(tgt) -> void:
	var c: Vector3 = tgt.global_position if tgt and is_instance_valid(tgt) else P.global_position + P.forward() * 6.0
	c.y = P.global_position.y
	cast(0.85, "OverhandThrow", 1.4)
	Game.fx.cracks(c, 3.2, Color(0.4, 0.8, 1.0), 2.5)
	at(0.39, func():
		Audio.sfx("shatter")
		Game.cam.shake(0.5)
		Game.fx.ice_spike(c, {"h": 3.4, "r": 0.5, "life": 2.4})
		for k in 12:
			var a := k / 12.0 * TAU + randf() * 0.3
			var rr := randf_range(0.6, 3.2)
			Game.after(k * 0.016, func(): Game.fx.ice_spike(c + Vector3(cos(a) * rr, 0, sin(a) * rr), {"h": randf_range(1.6, 3.2), "r": randf_range(0.2, 0.42), "life": 2.2, "silent": true}))
		Game.fx.shockwave(c, ICE, 4.0, {"glow": Color(0.4, 0.8, 1.0), "debris": false})
		for e in foes_in(3.6, c):
			hit(e, 44.0, {"heavy": true, "knock": 2.0, "launch": 9.0, "reaction": "launch", "element": "ice", "from": c, "crit": randf() < 0.2})
			e.add_frost(35.0))

## Gelo Negro — avança e agarra: o gelo negro sobe pelo braço do alvo até o osso estalar.
func _black_ice(tgt) -> void:
	cast(0.45, "Shield_Dash", 1.7, 14.0, 0.1)
	P.iframes = 0.3
	if tgt and is_instance_valid(tgt):
		P.snap_face(tgt.global_position)
	Audio.sfx("dodge")
	Game.fx.afterimage(P, Color(0.2, 0.3, 0.6), 0.3)
	var tries := [0]
	var ref := []
	ref.append(func():
		if not is_instance_valid(P) or P.state != "cast":
			return
		var found = null
		for e in foes_in(1.4, P.global_position + P.forward() * 1.0):
			found = e
			break
		if found:
			_grab(found)
		elif tries[0] < 6:
			tries[0] += 1
			Game.after(0.05, ref[0])
		else:
			_black_line())
	Game.after(0.08, ref[0])

func _black_line() -> void:
	var start: Vector3 = P.global_position
	var y: float = P.yaw
	for k in 8:
		Game.after(k * 0.04, func():
			var p := start + Game.fwd(y) * (k * 0.9 + 0.6) + Vector3(-cos(y), 0, sin(y)) * randf_range(-0.5, 0.5)
			Game.fx.ice_spike(p, {"black": true, "h": randf_range(0.8, 1.6), "r": 0.18, "life": 1.4, "silent": true}))
	area({"shape": "rect", "pos": start, "yaw": y, "width": 2.2, "length": 7.5, "dmg": 30.0, "delay": 0.2, "knock": 6.0, "element": "ice"})

func _grab(t) -> void:
	P.set_state("cast")
	P.cast_dur = 1.35
	P.cast_move = 0.0
	P.move_vel = Vector3.ZERO
	P.snap_face(t.global_position)
	P.rig.play("Melee_Hook", {"speed": 0.45, "blend": 0.05})
	t.apply_status("root", 1.4)
	if t is Player:
		t.cur_move = {}
		t.set_state("hit")
		t.state_lock = 1.4
		t.rig.play("Hit_Chest", {"speed": 0.6})
	Audio.sfx("ice")
	if Game.ui:
		Game.ui.toast("GELO NEGRO", Color(0.55, 0.7, 1.0), 0.9)
	var arm: Node3D = Game.fx.glow_ball(Color(0.05, 0.08, 0.2), 0.09)
	P.rig.attach_model(arm, "hand_r", Transform3D(Basis(), P.rig.skel.get_bone_global_rest(P.rig.skel.find_bone("hand_r")).origin))
	var aref := [arm]
	for k in 3:
		Game.after(0.25 + k * 0.25, func():
			if not is_instance_valid(t) or not t.alive or P.state != "cast": return
			Game.fx.ice_spike(t.global_position + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), {"black": true, "h": 0.9 + k * 0.35, "r": 0.16, "life": 1.6, "silent": true})
			Game.fx.burst("ice", t.chest_pos(), {"n": 8, "color": Color(0.2, 0.3, 0.6)})
			Audio.sfx("ice", 0.6)
			hit(t, 8.0, {"knock": 0.0, "reaction": "stagger", "unblockable": true, "unavoidable": true, "hitstop": 0.04, "element": "ice"}))
	Game.after(1.05, func():
		if is_instance_valid(aref[0]): aref[0].queue_free()
		if not is_instance_valid(t) or not t.alive: return
		Audio.sfx("crit")
		Audio.sfx("shatter")
		Game.cam.shake(0.6)
		if Game.post: Game.post.impact_frames(0.05, Color(0.75, 0.85, 1.0))
		Game.fx.impact(t.chest_pos(), Color(0.5, 0.7, 1.0), 2.6)
		hit(t, 26.0, {"heavy": true, "knock": 9.0, "reaction": "knockback", "unblockable": true, "unavoidable": true, "crit": true, "element": "ice"})
		t.stamina = 0.0
		t.apply_status("slow", 2.5, 0.6)
		t.add_frost(30.0))

# ---------------------------------------------------------------------
#  Despertar: Domínio do Inverno
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(10.0)
	Audio.sfx("fury")
	Audio.sfx("shatter")
	Game.cam.shake(0.8)
	Game.cam.kick(10.0)
	Game.slow(0.5, 0.2)
	if Game.post:
		Game.post.flash = 0.35
		Game.post.impact_frames(0.06, Color(0.85, 0.95, 1.0))
	Game.fx.shockwave(P.global_position, ICE, 14.0, {"glow": Color(0.4, 0.85, 1.0), "life": 1.1})
	for k in 16:
		var a := k / 16.0 * TAU
		var rr := randf_range(8.0, 12.0)
		Game.after(k * 0.02, func():
			var p: Vector3 = P.global_position + Vector3(cos(a) * rr, 0, sin(a) * rr)
			if Game.level and Game.level.has_method("clamp_point"):
				p = Game.level.clamp_point(p, 0.3)
			Game.fx.ice_spike(p, {"h": randf_range(1.2, 3.0), "r": randf_range(0.2, 0.45), "life": 10.0, "silent": true}))
	Game.fx.aura_end(P.aura_node)
	P.aura_node = Game.fx.aura(P, Color(0.45, 0.8, 1.0), Color(0.95, 0.98, 1.0), 1.6)
	P.rig.set_eye_glow(Color(0.6, 1.6, 2.4))
	if Game.ui:
		Game.ui.toast("— DOMÍNIO DO INVERNO —", Color(0.7, 0.92, 1.0), 1.8, true)

func awaken_tick(_delta: float) -> void:
	# neve caindo em volta
	for k in 2:
		var p: Vector3 = P.global_position + Vector3(randf_range(-10, 10), randf_range(4, 7), randf_range(-10, 10))
		Game.fx.emit("ice", p, Vector3(randf_range(-0.3, 0.3), -1.5, randf_range(-0.3, 0.3)), 3.0, 0.12, Color(0.9, 0.97, 1.0))

func awaken_end() -> void:
	P.rig.set_eye_glow(Color.BLACK)

# ---------------------------------------------------------------------
#  Ultimate: Punho Flamejante — o Mestre do Gelo manipulando o sol
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(0.5, 0.85, 1.0), Color(1.0, 1.0, 1.0), 2.0)
	# 1) o mundo congela
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 1.5, 0.5, 34.0, 1.3, -0.2), -0.18))
	Audio.sfx("reveal", 0.7)
	Audio.sfx("shatter", 0.8)
	if Game.post:
		Game.post.flash = 0.45
		Game.post.impact_frames(0.07, Color(0.85, 0.95, 1.0))
	Game.fx.shockwave(P.global_position, ICE, 14.0, {"glow": Color(0.4, 0.85, 1.0), "life": 1.2})
	for k in 14:
		var a := k / 14.0 * TAU
		var rr := randf_range(8.5, 11.0)
		var p: Vector3 = P.global_position + Vector3(cos(a) * rr, 0, sin(a) * rr)
		if Game.level and Game.level.has_method("clamp_point"):
			p = Game.level.clamp_point(p, 0.3)
		Game.fx.ice_spike(p, {"h": randf_range(1.2, 2.6), "r": randf_range(0.22, 0.4), "life": 3.6, "silent": true})
	if T and is_instance_valid(T):
		T.apply_status("freeze", 3.0)
	await U._wait(1.1)
	if U._aborted() or T == null or not is_instance_valid(T): return
	# 2) floresta de lanças empala o alvo
	Game.cam.shot(CamShots.dutch(CamShots.low_angle(P, T, 1.0, 4.8, 52.0, 1.2), 0.15))
	Audio.sfx("shatter")
	Game.cam.shake(0.7)
	var c: Vector3 = T.global_position
	Game.fx.ice_spike(c, {"h": 3.4, "r": 0.5, "life": 1.3})
	for k in 12:
		var a := k / 12.0 * TAU
		var rr := randf_range(0.7, 1.8)
		Game.after(k * 0.02, func(): Game.fx.ice_spike(c + Vector3(cos(a) * rr, 0, sin(a) * rr), {"h": randf_range(1.6, 3.0), "r": randf_range(0.22, 0.4), "life": 1.2, "silent": true}))
	T.break_freeze()
	U._hit(30.0, {"reaction": "launch", "launch": 7.0, "hitstop": 0.08, "shake": 0.5})
	await U._wait(0.95)
	if U._aborted() or not is_instance_valid(T): return
	# 3) o gelo negro no pescoço
	U._place_around(0.0, 1.0)
	T.vy = 0.0
	P.rig.play("Melee_Hook", {"speed": 0.3, "from": 0.05, "blend": 0.05})
	var arm: Node3D = Game.fx.glow_ball(Color(0.04, 0.06, 0.16), 0.11)
	P.rig.attach_model(arm, "hand_r", Transform3D(Basis(), P.rig.skel.get_bone_global_rest(P.rig.skel.find_bone("hand_r")).origin))
	Game.cam.shot(CamShots.dutch(CamShots.low_angle(P, T, 1.0, 3.0, 44.0, 2.0), -0.12))
	if Game.ui:
		Game.ui.bark("viktor", "Você se acha forte porque esmaga os fracos... mas diante de quem realmente conhece o desespero, você não passa de um ruído incômodo.", 3.2)
	for k in 3:
		Game.fx.ice_spike(T.global_position + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)), {"black": true, "h": 1.0 + k * 0.4, "r": 0.18, "life": 2.5, "silent": true})
	Audio.sfx("ice")
	U._hit(20.0, {"reaction": "stagger", "hitstop": 0.05})
	await U._wait(1.7)
	if is_instance_valid(arm): arm.queue_free()
	if U._aborted() or not is_instance_valid(T): return
	# 4) o sol na mão do Mestre do Gelo
	Game.cam.shot(CamShots.crash_zoom(P, T, 1.6))
	await U._wait(0.1)
	P.set_state("move")
	Game.main.get_tree().create_timer(0.3, false, false, true).timeout.connect(func():
		if Game.post: Game.post.impact_frames(0.1, Color(1.0, 0.92, 0.75)))
	P.punho_flamejante()
	await U._wait(1.4)
