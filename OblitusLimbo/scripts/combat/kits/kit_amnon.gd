extends FighterKit
## Amnon Akmenos — o tiefling exilado. Arqueiro de perto e brigão de taverna de perto:
## segurou com as mãos nuas o núcleo em chamas da criatura do Vale.
##  Passiva  Sangue Quente: resistente a fogo; quanto menos vida, mais dano (até +50%).
##  Habilidades: Flecha Carregada (perfura) · Garrafa de Hidromel (poça de fogo infernal) ·
##               Agarrão Infernal (agarra com as mãos em chamas e arremessa).
##  Despertar  Aposta Dobrada: joga a moeda — cara: dano dobrado; coroa: dano maior, mas apanha mais.
##  Ultimate   Chuva do Exílio.

const FIRE := Color(1.0, 0.45, 0.15)
var bet := ""          # "cara" | "coroa" durante o despertar

func stats() -> Dictionary:
	return {"hp": 120.0, "speed": 5.0, "sprint": 7.6, "color": FIRE, "chakra": Color(1.0, 0.45, 0.3),
		"name": "Amnon Akmenos", "title": "O Tiefling Exilado", "vs_hp": 450.0, "fury_gain": 1.15, "ai_range": 3.0}

func moves() -> Dictionary:
	return {
		"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
		"L1": {"anim": "Punch_Jab", "speed": 1.6, "type": "light", "lunge": 5.0,
			"hits": [{"t": 0.2, "dmg": 11.0, "range": 2.3, "arc": 1.8, "knock": 2.0, "reaction": "flinch"}],
			"combo": 0.24, "cancel": 0.0, "recover": 0.4, "end": 0.6, "next": {"light": "L2", "heavy": "L1H"}},
		"L2": {"anim": "Punch_Cross", "speed": 1.6, "type": "light", "lunge": 5.0,
			"hits": [{"t": 0.26, "dmg": 12.0, "range": 2.3, "arc": 1.8, "knock": 2.5, "reaction": "flinch"}],
			"combo": 0.3, "cancel": 0.0, "recover": 0.48, "end": 0.7, "next": {"light": "L3", "heavy": "L2H"}},
		"L3": {"anim": "Melee_Hook", "speed": 1.05, "type": "light", "lunge": 6.0,
			"hits": [{"t": 0.2, "dmg": 16.0, "range": 2.5, "arc": 2.0, "knock": 5.0, "reaction": "stagger", "fire": true}],
			"combo": 0.24, "cancel": 0.0, "recover": 0.36, "end": 0.47, "next": {"light": "L4", "heavy": "L3H"}},
		# ombrada de taverna em chamas
		"L4": {"anim": "Shield_Dash", "speed": 1.35, "type": "finisher", "lunge": 9.0, "lunge_t": 0.25,
			"hits": [{"t": 0.35, "dmg": 28.0, "range": 3.0, "arc": 3.0, "knock": 12.0, "reaction": "knockback", "fire": true, "finisher": true}],
			"combo": 99.0, "cancel": 0.5, "recover": 0.7, "end": 1.0, "next": {}},
		# pesado: flecha no arco
		"H1": {"anim": "Pistol_Shoot", "speed": 1.2, "type": "heavy", "lunge": 0.0,
			"hits": [{"t": 0.18, "proj": true, "kind": "arrow", "dmg": 18.0, "range": 20.0, "speed": 38.0, "color": FIRE}],
			"combo": 0.32, "cancel": 0.28, "recover": 0.45, "end": 0.6, "next": {"light": "L2", "heavy": "L2H"}},
		"L1H": {"anim": "Melee_Hook", "speed": 0.95, "type": "heavy", "lunge": 7.0,
			"hits": [{"t": 0.2, "dmg": 18.0, "range": 2.5, "arc": 1.8, "knock": 2.0, "launch": 8.0, "reaction": "launch", "fire": true}],
			"combo": 0.24, "cancel": 0.24, "recover": 0.38, "end": 0.47, "next": {"light": "L2", "heavy": "L3H"}},
		# L L → P: duas flechas rápidas à queima-roupa
		"L2H": {"anim": "Pistol_Shoot", "speed": 1.5, "type": "heavy", "lunge": 0.0,
			"hits": [{"t": 0.12, "proj": true, "kind": "arrow", "dmg": 11.0, "range": 16.0, "speed": 40.0, "color": FIRE},
				{"t": 0.3, "proj": true, "kind": "arrow", "dmg": 11.0, "range": 16.0, "speed": 40.0, "color": FIRE}],
			"combo": 0.36, "cancel": 0.3, "recover": 0.45, "end": 0.6, "next": {"light": "L3", "heavy": "L3H"}},
		# L L L → P: soco infernal que explode
		"L3H": {"anim": "Melee_Hook", "speed": 0.8, "type": "finisher", "lunge": 6.0,
			"hits": [{"t": 0.2, "dmg": 30.0, "range": 3.2, "arc": 6.3, "knock": 13.0, "launch": 4.0, "reaction": "knockback", "fire": true, "area": true, "finisher": true}],
			"combo": 99.0, "cancel": 0.3, "recover": 0.45, "end": 0.6, "next": {}},
		"DASH": {"anim": "Shield_Dash", "from": 0.1, "speed": 1.6, "type": "dash", "lunge": 11.0, "lunge_t": 0.22,
			"hits": [{"t": 0.22, "dmg": 16.0, "range": 2.6, "arc": 2.0, "knock": 6.0, "reaction": "stagger"}],
			"combo": 0.3, "cancel": 0.28, "recover": 0.5, "end": 0.75, "next": {"light": "L2", "heavy": "L2H"}},
		"CTR": {"anim": "Punch_Cross", "speed": 1.9, "type": "counter", "lunge": 9.0,
			"hits": [{"t": 0.26, "dmg": 22.0, "range": 2.6, "arc": 2.2, "knock": 6.0, "reaction": "stagger", "fire": true}],
			"combo": 0.3, "cancel": 0.0, "recover": 0.45, "end": 0.65, "next": {"light": "L3", "heavy": "L2H"}},
	}

func skills() -> Array:
	return [
		{"name": "Flecha Carregada", "cost": 16.0, "cd": 2.0, "icon": "chargedarrow", "ai": {"kind": "ranged", "range": 20.0}},
		{"name": "Garrafa de Hidromel", "cost": 20.0, "cd": 5.0, "icon": "bottle", "ai": {"kind": "trap", "range": 10.0}},
		{"name": "Agarrão Infernal", "cost": 25.0, "cd": 6.0, "icon": "hellgrab", "ai": {"kind": "grab", "range": 3.5}}]

func awaken_name() -> String:
	return "APOSTA DOBRADA"

func ult_info() -> Dictionary:
	return {"name": "CHUVA DO EXÍLIO", "col": FIRE, "rush": "Shield_Dash", "icon": "amnon_ult"}

func win_anim() -> String:
	return "Yes"

func trail_col(_m: Dictionary) -> Color:
	return Color(1.0, 0.8, 0.3) if bet == "cara" else FIRE

func trail_bone(m: Dictionary) -> String:
	return "hand_l" if m.get("anim", "") == "Punch_Jab" else "hand_r"

func dmg_mul() -> float:
	var hpf: float = clampf(P.hp / P.max_hp, 0.0, 1.0)
	var m := 1.0 + (1.0 - hpf) * 0.5
	if bet == "cara":
		m *= 2.0
	elif bet == "coroa":
		m *= 1.3
	return m

func incoming_mul(_src, o: Dictionary) -> float:
	var m := 0.5 if String(o.get("element", "")) == "fire" else 1.0
	if bet == "coroa":
		m *= 1.3
	return m

func modify_hit(_target, o: Dictionary, _m: Dictionary, h: Dictionary) -> Dictionary:
	if h.get("fire", false):
		o["element"] = "fire"
		o["spark"] = Color(1.0, 0.85, 0.5)
		o["spark2"] = Color(1.0, 0.3, 0.05)
	return o

func melee_fx(_m: Dictionary, h: Dictionary, pos: Vector3) -> void:
	if h.get("fire", false):
		var hp: Vector3 = P.rig.bone_world("hand_r")
		Game.fx.burst("fire", hp, {"n": 10, "r": 0.1, "size": 0.7, "color": Color(1, 0.9, 0.5), "color2": Color(1, 0.3, 0.05)})
		if h.get("finisher", false):
			Game.fx.burst("fire", pos + P.forward() * 1.2, {"n": 40, "r": 1.0, "size": 1.3, "up": 1.5})
			Audio.sfx("fire")

func tick(_delta: float) -> void:
	if P.hp / P.max_hp < 0.35 and randf() < 0.25:
		# sangue quente: brasas saindo das mãos
		Game.fx.burst("ember", P.rig.bone_world("hand_r" if randf() < 0.5 else "hand_l"), {"n": 1})

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _charged(tgt)
		1: _bottle(tgt)
		2: _grab_lunge(tgt)

func _charged(tgt) -> void:
	cast(0.75, "Pistol_Shoot", 0.75)
	Audio.sfx("fire", 0.4)
	var hold: Node3D = Game.fx.glow_ball(Color(2.4, 0.9, 0.3), 0.07)
	P.rig.attach_model(hold, "hand_l", Transform3D(Basis(), P.rig.skel.get_bone_global_rest(P.rig.skel.find_bone("hand_l")).origin))
	var href := [hold]
	at(0.42, func():
		if is_instance_valid(href[0]): href[0].queue_free()
		var start: Vector3 = P.global_position + Vector3(0, 1.35, 0) + P.forward() * 0.6
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("arrow")
		Audio.sfx("fire", 0.6)
		Game.cam.kick(4.0)
		proj({"kind": "arrow", "pos": start, "vel": dir * 46.0, "dmg": 30.0 * P.dmg_mul(), "radius": 0.45, "life": 1.0, "knock": 7.0, "heavy": true, "pierce": true,
			"color": FIRE, "glow": true, "element": "fire", "fury_gain": 3.0,
			"trail": func(p, _dt): Game.fx.burst("fire", p.pos, {"n": 1, "r": 0.03, "size": 0.6}),
			"on_hit": func(_p, t, ok): if ok and is_instance_valid(t): Game.fx.burst("fire", t.chest_pos(), {"n": 18})}))
	Game.after(0.8, func(): if is_instance_valid(href[0]): href[0].queue_free())

func _bottle(tgt) -> void:
	cast(0.55, "OverhandThrow", 1.6)
	at(0.33, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.6, 0) + P.forward() * 0.4
		var dest: Vector3 = tgt.global_position if tgt and is_instance_valid(tgt) else P.global_position + P.forward() * 7.0
		var flat: Vector3 = dest - start
		flat.y = 0
		var t_air := clampf(flat.length() / 13.0, 0.35, 0.9)
		var vel: Vector3 = flat / t_air + Vector3(0, (dest.y - start.y) / t_air + 0.5 * 20.0 * t_air, 0)
		Audio.sfx("whoosh", 0.6)
		proj({"kind": "bottle", "pos": start, "vel": vel, "gravity": 20.0, "dmg": 10.0 * P.dmg_mul(), "radius": 0.5, "life": t_air + 0.15, "knock": 3.0,
			"element": "fire", "fury_gain": 1.5,
			"on_expire": func(p): _bottle_burst(p.pos)}))

func _bottle_burst(at_pos: Vector3) -> void:
	var c := Vector3(at_pos.x, P.global_position.y, at_pos.z)
	Audio.sfx("shatter", 0.7)
	Audio.sfx("fire")
	Game.fx.burst("fire", c + Vector3(0, 0.3, 0), {"n": 40, "r": 0.8, "size": 1.2, "up": 1.5})
	Game.fx.burst("spark", c + Vector3(0, 0.4, 0), {"n": 14, "color": Color(1, 0.9, 0.6)})
	Game.fx.shockwave(c, FIRE, 2.5, {"glow": Color(1.0, 0.4, 0.1), "debris": false, "cracks": false})
	for e in foes_in(2.4, c):
		hit(e, 16.0, {"knock": 4.0, "element": "fire", "reaction": "stagger", "from": c})
	Game.add_hazard({"kind": "fire", "pos": c, "radius": 2.0, "dps": 13.0 * P.dmg_mul(), "life": 4.0, "team": P.team, "src": P})

func _grab_lunge(tgt) -> void:
	cast(0.45, "Shield_Dash", 1.7, 13.0, 0.1)
	P.iframes = 0.25
	if tgt and is_instance_valid(tgt):
		P.snap_face(tgt.global_position)
	Audio.sfx("dodge")
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
			_hell_grab(found)
		elif tries[0] < 6:
			tries[0] += 1
			Game.after(0.05, ref[0]))
	Game.after(0.08, ref[0])

## Agarrão Infernal: segura o alvo com as mãos em chamas (como o núcleo do Vale) e arremessa.
func _hell_grab(t) -> void:
	P.set_state("cast")
	P.cast_dur = 1.25
	P.cast_move = 0.0
	P.move_vel = Vector3.ZERO
	P.snap_face(t.global_position)
	P.rig.play("Melee_Hook", {"speed": 0.4, "blend": 0.05})
	t.apply_status("root", 1.2)
	if t is Player:
		t.cur_move = {}
		t.set_state("hit")
		t.state_lock = 1.25
		t.rig.play("Hit_Chest", {"speed": 0.6})
	if Game.ui:
		Game.ui.toast("AGARRÃO INFERNAL", FIRE, 0.9)
	for k in 3:
		Game.after(0.2 + k * 0.25, func():
			if not is_instance_valid(t) or not t.alive or P.state != "cast": return
			Game.fx.burst("fire", t.chest_pos(), {"n": 14, "r": 0.3, "size": 0.9})
			Audio.sfx("fire", 0.6)
			hit(t, 7.0, {"knock": 0.0, "reaction": "stagger", "unblockable": true, "unavoidable": true, "element": "fire", "hitstop": 0.04}))
	Game.after(1.0, func():
		if not is_instance_valid(t) or not t.alive: return
		Audio.sfx("hitHeavy")
		Audio.sfx("explosion", 0.6)
		Game.cam.shake(0.6)
		Game.fx.burst("fire", t.chest_pos(), {"n": 50, "r": 0.6, "size": 1.4, "up": 1.5})
		Game.fx.impact(t.chest_pos(), FIRE, 2.6)
		hit(t, 24.0, {"heavy": true, "knock": 14.0, "launch": 4.0, "reaction": "knockback", "unblockable": true, "unavoidable": true, "crit": true, "element": "fire"}))

# ---------------------------------------------------------------------
#  Despertar: Aposta Dobrada
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(9.0)
	bet = "cara" if randf() < 0.65 else "coroa"
	Audio.sfx("bell", 0.8)
	var coin: Node3D = Game.fx.glow_ball(Color(2.6, 2.0, 0.6), 0.08)
	Game.world.add_child(coin)
	var c0: Vector3 = P.global_position + Vector3(0, 1.5, 0)
	coin.global_position = c0
	var cref := [coin]
	Game.fx.custom(0.7, func(t, _dt):
		if is_instance_valid(cref[0]): cref[0].global_position = c0 + Vector3(0, sin(t / 0.7 * PI) * 1.6, 0), func():
		if is_instance_valid(cref[0]): cref[0].queue_free())
	Game.after(0.7, func():
		if not is_instance_valid(P): return
		Game.fx.aura_end(P.aura_node)
		if bet == "cara":
			P.aura_node = Game.fx.aura(P, Color(1.0, 0.75, 0.2), Color(1.0, 0.95, 0.6), 1.5)
			Game.fx.burst("gold", P.global_position + Vector3(0, 1, 0), {"n": 40, "r": 0.8})
			Audio.sfx("uiOk")
			if Game.ui: Game.ui.toast("CARA! — DANO DOBRADO", Color(1, 0.85, 0.35), 1.8, true)
		else:
			P.aura_node = Game.fx.aura(P, Color(1.0, 0.25, 0.1), Color(0.3, 0.05, 0.02), 1.4)
			Game.fx.burst("fire", P.global_position + Vector3(0, 1, 0), {"n": 30, "r": 0.6})
			if Game.ui: Game.ui.toast("COROA... DEVENDO NO OUTRO MUNDO", Color(1, 0.45, 0.3), 1.8, true))

func awaken_end() -> void:
	bet = ""

func reset() -> void:
	bet = ""

# ---------------------------------------------------------------------
#  Ultimate: Chuva do Exílio
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(1.0, 0.4, 0.1), Color(1.0, 0.85, 0.4), 1.8)
	# salta e mira para o céu
	Game.cam.shot(CamShots.dutch(CamShots.low_angle(P, T, -1.0, 4.0, 52.0, 1.4), 0.18))
	P.rig.play("NinjaJump_Start", {"speed": 1.2, "blend": 0.05})
	P.vy = 9.0
	Audio.sfx("whoosh")
	await U._wait(0.45)
	if U._aborted() or T == null or not is_instance_valid(T): return
	P.rig.play("Pistol_Shoot", {"speed": 0.8, "blend": 0.05})
	Audio.sfx("arrow")
	Game.fx.beam(P.global_position + Vector3(0, 1.5, 0), P.global_position + Vector3(0, 30, 0), {"color": FIRE, "width": 0.06, "life": 0.4})
	await U._wait(0.5)
	if U._aborted() or not is_instance_valid(T): return
	# chuva de flechas em chamas
	Game.cam.shot(CamShots.orbit(T.global_position, 7.0, 4.0, P.yaw + 0.5, P.yaw + 1.6, 2.0, 0.8, 56.0))
	for k in 14:
		var p: Vector3 = T.global_position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		var v: Node3D = Game.fx.projectile_visual("arrow", {"color": FIRE, "glow": true})
		Game.world.add_child(v)
		var top := p + Vector3(randf_range(-1, 1), 14.0, randf_range(-1, 1))
		v.global_position = top
		v.look_at(p, Vector3.RIGHT)
		var vr := [v]
		var dl := 0.25 + randf() * 0.2
		Game.fx.custom(dl, func(t, _dt):
			if is_instance_valid(vr[0]): vr[0].global_position = top.lerp(p, t / dl), func():
			if is_instance_valid(vr[0]): vr[0].queue_free()
			Game.fx.burst("fire", p + Vector3(0, 0.2, 0), {"n": 10, "r": 0.2, "size": 0.9, "up": 1.2}))
		if k % 2 == 0:
			U._hit(6.0, {"hitstop": 0.02, "reaction": "flinch"})
		await U._wait(0.09)
	if U._aborted() or not is_instance_valid(T): return
	# cai com o soco infernal
	U._place_around(0.0, 1.4)
	Game.cam.shot(CamShots.crash_zoom(P, T, 1.3))
	P.rig.play("Melee_Hook", {"speed": 0.7, "blend": 0.0})
	await U._wait(0.25)
	Audio.sfx("explosion")
	Audio.sfx("crit")
	if Game.post:
		Game.post.impact_frames(0.09, Color(1.0, 0.85, 0.7))
		Game.post.flash = 0.4
	Game.fx.burst("fire", T.chest_pos(), {"n": 80, "r": 1.2, "size": 1.6, "up": 2.0})
	Game.fx.shockwave(T.global_position, FIRE, 7.0, {"glow": Color(1.0, 0.45, 0.1)})
	Game.fx.impact(T.chest_pos(), FIRE, 4.0)
	Game.add_hazard({"kind": "fire", "pos": T.global_position, "radius": 2.6, "dps": 10.0, "life": 3.0, "team": P.team, "src": P})
	U._hit(62.0, {"knock": 13.0, "reaction": "knockback", "hitstop": 0.2, "shake": 0.8, "crit": true, "element": "fire"})
	Game.slow(0.6, 0.3)
	await U._wait(0.8)
