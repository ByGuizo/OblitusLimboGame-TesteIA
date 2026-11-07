extends FighterKit
## Near Shade — o elfo da máscara, ladino de passos fantasmagóricos.
##  Passiva  Ataque Furtivo: golpes pelas costas são críticos garantidos (+50%).
##           Esquiva perfeita = some por 1 s (o próximo golpe sai pelas costas).
##  Combo    duas adagas, 5 golpes rápidos; finalizador atravessa e termina atrás do alvo.
##  Habilidades: Adagas de Arremesso · Véu da Sombra (invisível; o próximo golpe é uma emboscada) ·
##               Bomba de Fumaça (cega quem está dentro e ele recua).
##  Despertar  Sombra Gêmea: um clone de sombra repete cada golpe.
##  Ultimate   Mil Cortes no Escuro.

const SHADOW := Color(0.6, 0.45, 1.0)
var veil_t := 0.0
var ambush := false
var _wisp_t := 0.0
var clone: CharRig = null

func stats() -> Dictionary:
	return {"hp": 85.0, "speed": 5.7, "sprint": 8.6, "color": Color(0.78, 0.72, 1.0), "chakra": Color(0.55, 0.4, 0.9),
		"name": "Near Shade", "title": "O Elfo da Máscara", "vs_hp": 370.0, "fury_gain": 1.1, "ai_range": 1.8}

func moves() -> Dictionary:
	return {
		"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
		"L1": {"anim": "Sword_Regular_A", "speed": 1.8, "type": "light", "lunge": 6.0,
			"hits": [{"t": 0.13, "dmg": 8.0, "range": 2.2, "arc": 2.2, "knock": 1.5, "reaction": "flinch", "slash": {"roll": -0.3}}],
			"combo": 0.15, "cancel": 0.0, "recover": 0.26, "end": 0.38, "next": {"light": "L2", "heavy": "L1H"}},
		"L2": {"anim": "Sword_Regular_B", "speed": 1.8, "type": "light", "lunge": 6.0,
			"hits": [{"t": 0.19, "dmg": 8.0, "range": 2.2, "arc": 2.2, "knock": 1.5, "reaction": "flinch", "slash": {"roll": 0.7, "flip": true}}],
			"combo": 0.21, "cancel": 0.0, "recover": 0.32, "end": 0.46, "next": {"light": "L3", "heavy": "L2H"}},
		"L3": {"anim": "Sword_Regular_A", "speed": 2.1, "type": "light", "lunge": 6.0,
			"hits": [{"t": 0.13, "dmg": 9.0, "range": 2.2, "arc": 2.2, "knock": 1.5, "reaction": "flinch", "slash": {"roll": 0.3, "flip": true}}],
			"combo": 0.15, "cancel": 0.0, "recover": 0.26, "end": 0.36, "next": {"light": "L4", "heavy": "L3H"}},
		"L4": {"anim": "Sword_Regular_B", "speed": 2.1, "type": "light", "lunge": 6.0,
			"hits": [{"t": 0.19, "dmg": 10.0, "range": 2.3, "arc": 2.2, "knock": 2.0, "reaction": "stagger", "slash": {"roll": -0.8}}],
			"combo": 0.21, "cancel": 0.0, "recover": 0.32, "end": 0.44, "next": {"light": "L5", "heavy": "L3H"}},
		# atravessa o alvo e termina nas costas dele
		"L5": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.9, "type": "finisher", "lunge": 13.0, "lunge_t": 0.2,
			"hits": [{"t": 0.22, "dmg": 22.0, "range": 2.8, "arc": 2.4, "knock": 9.0, "reaction": "knockback", "behind": true, "finisher": true, "slash": {"roll": 1.5, "big": true}}],
			"combo": 99.0, "cancel": 0.3, "recover": 0.5, "end": 0.7, "next": {}},
		# pesado: leque de adagas
		"H1": {"anim": "OverhandThrow", "speed": 1.7, "type": "heavy", "lunge": 0.0,
			"hits": [{"t": 0.5, "proj": true, "kind": "knife", "dmg": 13.0, "range": 16.0, "speed": 30.0, "fan": 3}],
			"combo": 0.6, "cancel": 0.5, "recover": 0.75, "end": 0.95, "next": {"light": "L2", "heavy": "L2H"}},
		# L → P: rasteira deslizando que lança
		"L1H": {"anim": "Slide_Start", "speed": 1.5, "type": "heavy", "lunge": 11.0, "lunge_t": 0.3,
			"hits": [{"t": 0.3, "dmg": 12.0, "range": 2.4, "arc": 1.8, "knock": 2.0, "launch": 7.0, "reaction": "launch"}],
			"combo": 0.4, "cancel": 0.35, "recover": 0.55, "end": 0.75, "next": {"light": "L3", "heavy": "L3H"}},
		# L L → P: some e reaparece atrás com um corte
		"L2H": {"anim": "Sword_Regular_C", "from": 0.3, "speed": 1.7, "type": "heavy", "lunge": 4.0,
			"hits": [{"t": 0.28, "dmg": 16.0, "range": 2.6, "arc": 2.0, "knock": 4.0, "reaction": "stagger", "behind": true, "slash": {"roll": 1.4, "big": true}}],
			"combo": 0.34, "cancel": 0.3, "recover": 0.55, "end": 0.8, "next": {"light": "L4", "heavy": "L3H"}},
		# L L L → P: mergulho com as duas adagas
		"L3H": {"anim": "NinjaJump_Land", "speed": 1.3, "type": "finisher", "lunge": 5.0, "jump": 6.5,
			"hits": [{"t": 0.32, "dmg": 26.0, "range": 3.2, "arc": 6.3, "knock": 11.0, "launch": 3.0, "reaction": "knockback", "area": true, "finisher": true, "slash": {"roll": 1.57, "big": true}}],
			"combo": 99.0, "cancel": 0.45, "recover": 0.7, "end": 0.95, "next": {}},
		"DASH": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.9, "type": "dash", "lunge": 12.0, "lunge_t": 0.2,
			"hits": [{"t": 0.22, "dmg": 13.0, "range": 2.6, "arc": 2.0, "knock": 5.0, "reaction": "stagger", "slash": {"roll": 1.5}}],
			"combo": 0.28, "cancel": 0.26, "recover": 0.5, "end": 0.7, "next": {"light": "L3", "heavy": "L2H"}},
		"CTR": {"anim": "Sword_Regular_B", "speed": 2.0, "type": "counter", "lunge": 10.0,
			"hits": [{"t": 0.19, "dmg": 18.0, "range": 2.6, "arc": 2.4, "knock": 5.0, "reaction": "stagger", "behind": true, "slash": {"roll": 0.75, "flip": true, "big": true}}],
			"combo": 0.22, "cancel": 0.0, "recover": 0.34, "end": 0.48, "next": {"light": "L4", "heavy": "L2H"}},
	}

func skills() -> Array:
	return [
		{"name": "Adagas de Arremesso", "cost": 14.0, "cd": 1.4, "icon": "knives", "ai": {"kind": "ranged", "range": 14.0}},
		{"name": "Véu da Sombra", "cost": 25.0, "cd": 8.0, "icon": "veil", "ai": {"kind": "buff", "range": 20.0}},
		{"name": "Bomba de Fumaça", "cost": 20.0, "cd": 6.0, "icon": "smoke", "ai": {"kind": "aoe", "range": 3.5}}]

func awaken_name() -> String:
	return "SOMBRA GÊMEA"

func ult_info() -> Dictionary:
	return {"name": "MIL CORTES NO ESCURO", "col": Color(0.55, 0.35, 1.0), "rush": "Sword_Dash", "icon": "near_ult"}

func win_anim() -> String:
	return "Idle_FoldArms"

func trail_col(_m: Dictionary) -> Color:
	return Color(0.5, 0.3, 1.0) if P.awakened else Color(0.75, 0.7, 1.0)

func trail_bone(m: Dictionary) -> String:
	return "hand_l" if m.get("anim", "") == "Sword_Regular_B" else "hand_r"

func dodge_fx() -> void:
	Game.fx.afterimage(P, SHADOW, 0.4)
	Game.fx.burst("shadow", P.global_position + Vector3(0, 0.8, 0), {"n": 10, "r": 0.3, "color": Color(0.1, 0.06, 0.16)})

# ---------------------------------------------------------------------
#  Passiva: Ataque Furtivo
# ---------------------------------------------------------------------
func _behind(target) -> bool:
	var to_me: Vector3 = P.global_position - target.global_position
	to_me.y = 0
	if to_me.length() < 0.01:
		return false
	return to_me.normalized().dot(Game.fwd(target.yaw)) < -0.35

func modify_hit(target, o: Dictionary, _m: Dictionary, h: Dictionary) -> Dictionary:
	o["spark"] = Color(0.85, 0.8, 1.0)
	o["spark2"] = Color(0.4, 0.2, 0.9)
	if ambush or _behind(target):
		o["crit"] = true
		o["dmg_mul"] = 1.8 if ambush else 1.5
		o["sneak"] = true
	if h.get("behind", false):
		o["behind"] = true
	return o

func on_hit_dealt(target, amount: float, o: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	if o.get("sneak", false) and Game.ui and P.brain == null:
		Game.ui.toast("FURTIVO!", Color(0.75, 0.6, 1.0), 0.5)
	ambush = false
	if o.get("behind", false) and target.alive:
		_appear_behind(target, 1.1)
	if P.awakened and target.alive and amount > 0.0 and not o.get("clone", false):
		# Sombra Gêmea repete o golpe
		var t2 = target
		Game.after(0.12, func():
			if is_instance_valid(t2) and t2.alive and is_instance_valid(P):
				Game.fx.slash(t2.chest_pos(), P.yaw + PI * 0.5, {"color": Color(0.4, 0.2, 0.9), "dark": true, "intensity": 2.4})
				Game.damage(P, t2, amount * 0.5, {"knock": 1.0, "reaction": "flinch", "clone": true, "spark": Color(0.6, 0.4, 1.0), "fury_gain": 1.0}))

func on_perfect_dodge(_src) -> void:
	_start_veil(1.0, false)

func _appear_behind(target, dist := 1.1) -> void:
	var behind: Vector3 = target.global_position - Game.fwd(target.yaw) * (target.radius + dist)
	if Game.level and Game.level.has_method("clamp_point"):
		behind = Game.level.clamp_point(behind, P.radius)
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 10, "r": 0.35, "color": Color(0.1, 0.05, 0.18)})
	P.global_position = Vector3(behind.x, P.global_position.y, behind.z)
	P.snap_face(target.global_position)
	Game.fx.afterimage(P, SHADOW, 0.3)
	Audio.sfx("blink", 0.6)

# ---------------------------------------------------------------------
#  Véu (invisibilidade)
# ---------------------------------------------------------------------
func _start_veil(t: float, announce := true) -> void:
	veil_t = t
	ambush = true
	P.untargetable = true
	P.rig.visible = false
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 24, "r": 0.5, "speed": 2.0, "color": Color(0.08, 0.04, 0.14)})
	Audio.sfx("blink")
	if announce and Game.ui and P.brain == null:
		Game.ui.toast("VÉU DA SOMBRA", SHADOW, 0.8)

func _end_veil() -> void:
	veil_t = 0.0
	P.untargetable = false
	P.rig.visible = true
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 12, "r": 0.4, "color": Color(0.1, 0.05, 0.18)})

func on_attack_start(_m: Dictionary) -> void:
	if veil_t > 0.0:
		# emboscada: reaparece nas costas do alvo
		var t = P.opponent if P.opponent and is_instance_valid(P.opponent) else P.auto_target(14.0)
		if t == null:
			t = Game.nearest_enemy(P, 14.0)
		_end_veil()
		if t and is_instance_valid(t):
			_appear_behind(t, 0.9)

func move_mul() -> float:
	return 1.25 if veil_t > 0.0 else 1.0

func tick(delta: float) -> void:
	if veil_t > 0.0:
		veil_t -= delta
		_wisp_t -= delta
		if _wisp_t <= 0.0:
			_wisp_t = 0.12
			Game.fx.emit("shadow", P.global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0.1, 1.4), randf_range(-0.2, 0.2)), Vector3(0, 0.4, 0), 0.6, 0.5, Color(0.12, 0.08, 0.2, 0.6))
		if veil_t <= 0.0:
			_end_veil()
	if clone and is_instance_valid(clone):
		var right := Vector3(-cos(P.yaw), 0, sin(P.yaw))
		var want: Vector3 = P.global_position + right * 0.9 - P.forward() * 0.6
		clone.global_position = clone.global_position.lerp(want, minf(1.0, delta * 12.0))
		clone.rotation.y = P.yaw
		clone.set_loco(P.speed, P.sprinting)

func cleanup() -> void:
	_kill_clone()

func reset() -> void:
	veil_t = 0.0
	ambush = false
	_kill_clone()

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _knives(tgt)
		1: _start_veil(3.0)
		2: _smoke()

func fire_hit(m: Dictionary, h: Dictionary) -> void:
	_throw(P.auto_target(16.0), int(h.get("fan", 3)), float(h.dmg))

func _throw(tgt, n: int, dmg: float) -> void:
	var start: Vector3 = P.global_position + Vector3(0, 1.3, 0) + P.forward() * 0.5
	var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt else P.forward()
	if tgt:
		P.snap_face(tgt.global_position)
	Audio.sfx("swing")
	for k in n:
		var a := (k - (n - 1) * 0.5) * 0.13
		proj({"kind": "knife", "pos": start, "vel": dir.rotated(Vector3.UP, a) * 30.0, "dmg": dmg * P.dmg_mul(), "radius": 0.35, "life": 0.9, "knock": 1.5,
			"color": SHADOW, "target": tgt, "homing": 1.2, "fury_gain": 1.5,
			"trail": func(p, _dt): if randf() < 0.5: Game.fx.burst("shadow", p.pos, {"n": 1, "r": 0.02, "speed": 0.1, "color": Color(0.2, 0.1, 0.3)}),
			"on_hit": func(_p, t, ok):
				if ok and is_instance_valid(t):
					t.apply_status("slow", 1.0, 0.8)
					Game.fx.burst("spark", t.chest_pos(), {"n": 6, "color": Color(0.85, 0.8, 1.0)})})

func _knives(tgt) -> void:
	cast(0.4, "OverhandThrow", 2.2, 0.0, 0.25)
	at(0.12, func(): _throw(tgt, 3, 11.0))

func _smoke() -> void:
	var c: Vector3 = P.global_position
	Audio.sfx("explosion", 0.4)
	Audio.sfx("wind", 0.6)
	Game.fx.smoke_cloud(c, 3.4, 3.2)
	Game.fx.burst("smoke", c + Vector3(0, 0.6, 0), {"n": 30, "r": 1.2, "speed": 2.5, "size": 2.0})
	for e in foes_in(3.6, c):
		e.apply_status("blind", 2.6)
		e.apply_status("slow", 2.0, 0.7)
	# salto para trás saindo da fumaça
	P.dodge_dir = -P.forward()
	P.dodge_t = 0.0
	P.iframes = 0.45
	P.set_state("dodge")
	P.rig.play("Roll", {"speed": 2.0, "blend": 0.04})
	_start_veil(1.2, false)

# ---------------------------------------------------------------------
#  Despertar: Sombra Gêmea
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(10.0)
	Audio.sfx("fury")
	Game.cam.shake(0.4)
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 40, "r": 0.7, "speed": 3.0, "size": 1.4, "color": Color(0.12, 0.05, 0.2)})
	Game.fx.aura_end(P.aura_node)
	P.aura_node = Game.fx.aura(P, Color(0.45, 0.25, 0.95), Color(0.1, 0.05, 0.2), 1.3)
	_kill_clone()
	clone = CharFactory.build("near", {})
	Game.world.add_child(clone)
	clone.global_position = P.global_position
	clone.set_cloth_active(false)
	clone.set_tint(0.12, Color(0.5, 0.3, 1.0))
	clone.combat = true
	if Game.ui:
		Game.ui.toast("— SOMBRA GÊMEA —", SHADOW, 1.6, true)

func on_attack_start_clone(m: Dictionary) -> void:
	if clone and is_instance_valid(clone):
		clone.play(m.anim, {"speed": float(m.speed) * 1.05, "from": float(m.get("from", 0.0)), "blend": 0.06})

func awaken_tick(_delta: float) -> void:
	if clone and is_instance_valid(clone) and P.state == "attack" and P.state_t < 0.02 and P.cur_move.has("anim"):
		on_attack_start_clone(P.cur_move)

func awaken_end() -> void:
	_kill_clone()

func _kill_clone() -> void:
	if clone and is_instance_valid(clone):
		Game.fx.burst("shadow", clone.global_position + Vector3(0, 1, 0), {"n": 18, "r": 0.5, "color": Color(0.1, 0.05, 0.18)})
		clone.queue_free()
	clone = null

# ---------------------------------------------------------------------
#  Ultimate: Mil Cortes no Escuro
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(0.45, 0.25, 0.95), Color(0.08, 0.04, 0.16), 1.6)
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 1.3, 0.4, 34.0, 0.9), 0.16))
	Audio.sfx("blink")
	if Game.post:
		Game.post.vig = 1.6
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 40, "r": 0.6, "speed": 3.0, "size": 1.5, "color": Color(0.06, 0.03, 0.1)})
	await U._wait(0.7)
	for i in 9:
		if U._aborted() or T == null or not is_instance_valid(T): break
		var ang := randf() * TAU
		U._place_around(ang, 1.3)
		P.rig.play("Sword_Regular_A" if i % 2 == 0 else "Sword_Regular_B", {"speed": 2.6, "blend": 0.0})
		if i % 3 == 0:
			Game.cam.shot(CamShots.dutch(CamShots.around(T, ang + PI * 0.7, 2.8, 1.2 + (i % 2) * 0.8, 46.0, 0.3), 0.25 if i % 2 else -0.25))
		Game.fx.afterimage(P, SHADOW, 0.5)
		Game.fx.slash(T.chest_pos(), randf() * TAU, {"color": Color(0.55, 0.35, 1.0), "dark": true, "intensity": 3.0, "roll": randf_range(-1.5, 1.5), "big": true})
		U._hit(7.0, {"hitstop": 0.03, "reaction": "flinch"})
		await U._wait(0.11)
	if U._aborted() or T == null or not is_instance_valid(T):
		if Game.post: Game.post.vig = 0.0
		return
	# guarda as adagas de costas para o alvo... e os cortes chegam depois
	U._place_around(PI, 2.2)
	P.snap_face(P.global_position + (P.global_position - T.global_position))
	P.rig.play("Sword_Idle", {"speed": 0.8, "blend": 0.1})
	Game.cam.shot(CamShots.low_angle(P, T, 1.0, 4.2, 48.0, 1.4))
	await U._wait(0.75)
	if U._aborted() or not is_instance_valid(T):
		if Game.post: Game.post.vig = 0.0
		return
	Audio.sfx("crit")
	Audio.sfx("swingHeavy")
	if Game.post:
		Game.post.impact_frames(0.09, Color(0.85, 0.75, 1.0))
		Game.post.vig = 0.0
	for k in 7:
		Game.fx.slash(T.chest_pos(), randf() * TAU, {"color": Color(0.7, 0.5, 1.0), "intensity": 3.4, "roll": randf_range(-1.6, 1.6), "big": true})
	Game.fx.impact(T.chest_pos(), Color(0.65, 0.45, 1.0), 4.0)
	U._hit(70.0, {"knock": 12.0, "reaction": "knockback", "hitstop": 0.2, "shake": 0.8, "crit": true})
	Game.slow(0.6, 0.3)
	await U._wait(0.8)
