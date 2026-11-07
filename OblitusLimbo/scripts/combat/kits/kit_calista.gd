extends FighterKit
## Calista Vanshee — a arqueira de EmberFall. Manipulação de Fios de Sangue, limitada com
## segurança pelo próprio arco: flechas "imbuídas em fios carmesins" que restringem o inimigo;
## contra Krauser, usou os fios como agulhas de aço. Voou impulsionada pelo vento. Lê runas.
##  Estilo   zoner: tiros rápidos à distância; pesado afasta quem chega perto.
##  Habilidades: Flecha de Fio Carmesim (prende) · Agulhas de Sangue (leque) ·
##               Runa do Vento (empurra e salta para trás).
##  Despertar  Teia Carmesim: cada acerto amarra o alvo por um instante.
##  Ultimate   Rede da Lua.

const BLOOD := Color(1.0, 0.15, 0.25)

func stats() -> Dictionary:
	return {"hp": 110.0, "speed": 5.3, "sprint": 8.0, "color": BLOOD, "chakra": Color(1.0, 0.3, 0.4),
		"name": "Calista Vanshee", "title": "A Arqueira de EmberFall", "vs_hp": 400.0, "fury_gain": 1.1, "ai_range": 7.0}

func moves() -> Dictionary:
	var shot := func(dmg: float, spd := 40.0) -> Dictionary:
		return {"proj": true, "kind": "arrow", "dmg": dmg, "range": 22.0, "speed": spd, "color": BLOOD, "homing": 2.0}
	var h1: Dictionary = shot.call(8.0)
	h1["t"] = 0.16
	var h2: Dictionary = shot.call(8.0)
	h2["t"] = 0.16
	var h3a: Dictionary = shot.call(7.0, 44.0)
	h3a["t"] = 0.12
	var h3b: Dictionary = shot.call(7.0, 44.0)
	h3b["t"] = 0.3
	var h4: Dictionary = shot.call(22.0, 52.0)
	h4["t"] = 0.3
	h4["pierce"] = true
	h4["big"] = true
	return {
		"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
		"L1": {"anim": "Pistol_Shoot", "speed": 1.7, "type": "light", "lunge": 0.0, "hits": [h1],
			"combo": 0.2, "cancel": 0.0, "recover": 0.3, "end": 0.42, "next": {"light": "L2", "heavy": "L1H"}},
		"L2": {"anim": "Pistol_Shoot", "speed": 1.7, "type": "light", "lunge": 0.0, "hits": [h2],
			"combo": 0.2, "cancel": 0.0, "recover": 0.3, "end": 0.42, "next": {"light": "L3", "heavy": "L2H"}},
		"L3": {"anim": "Pistol_Shoot", "speed": 1.6, "type": "light", "lunge": 0.0, "hits": [h3a, h3b],
			"combo": 0.36, "cancel": 0.0, "recover": 0.45, "end": 0.55, "next": {"light": "L4", "heavy": "L3H"}},
		# flecha perfurante
		"L4": {"anim": "Pistol_Shoot", "speed": 0.9, "type": "finisher", "lunge": 0.0, "hits": [h4],
			"combo": 99.0, "cancel": 0.35, "recover": 0.5, "end": 0.62, "next": {}},
		# pesado: golpe com o arco que afasta
		"H1": {"anim": "Melee_Hook", "speed": 1.0, "type": "heavy", "lunge": 5.0,
			"hits": [{"t": 0.2, "dmg": 16.0, "range": 2.5, "arc": 2.0, "knock": 12.0, "reaction": "knockback"}],
			"combo": 0.26, "cancel": 0.24, "recover": 0.38, "end": 0.47, "next": {"light": "L2", "heavy": "L2H"}},
		"L1H": {"anim": "Shield_OneShot", "speed": 1.4, "type": "heavy", "lunge": 3.0,
			"hits": [{"t": 0.3, "dmg": 14.0, "range": 2.8, "arc": 3.0, "knock": 3.0, "launch": 7.5, "reaction": "launch", "thread": true}],
			"combo": 0.4, "cancel": 0.35, "recover": 0.55, "end": 0.75, "next": {"light": "L3", "heavy": "L3H"}},
		# L L → P: três flechas em leque
		"L2H": {"anim": "Pistol_Shoot", "speed": 1.2, "type": "heavy", "lunge": 0.0,
			"hits": [{"t": 0.18, "proj": true, "kind": "arrow", "dmg": 10.0, "range": 18.0, "speed": 40.0, "color": BLOOD, "fan": 3}],
			"combo": 0.34, "cancel": 0.3, "recover": 0.45, "end": 0.6, "next": {"light": "L3", "heavy": "L3H"}},
		# L L L → P: chuva curta de flechas sobre o alvo (finalizador)
		"L3H": {"anim": "Spell_Simple_Shoot", "speed": 0.9, "type": "finisher", "lunge": 0.0,
			"hits": [{"t": 0.25, "proj": true, "kind": "rain", "dmg": 28.0, "range": 18.0}],
			"combo": 99.0, "cancel": 0.4, "recover": 0.5, "end": 0.6, "next": {}},
		"DASH": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.8, "type": "dash", "lunge": 10.0, "lunge_t": 0.2,
			"hits": [{"t": 0.22, "dmg": 13.0, "range": 2.5, "arc": 2.0, "knock": 8.0, "reaction": "knockback"}],
			"combo": 0.3, "cancel": 0.28, "recover": 0.5, "end": 0.7, "next": {"light": "L2", "heavy": "L2H"}},
		"CTR": {"anim": "Pistol_Shoot", "speed": 2.0, "type": "counter", "lunge": 0.0,
			"hits": [{"t": 0.14, "proj": true, "kind": "arrow", "dmg": 18.0, "range": 18.0, "speed": 50.0, "color": BLOOD, "root": 0.6}],
			"combo": 0.22, "cancel": 0.0, "recover": 0.3, "end": 0.4, "next": {"light": "L3", "heavy": "L2H"}},
	}

func skills() -> Array:
	return [
		{"name": "Fio Carmesim", "cost": 15.0, "cd": 3.0, "icon": "thread", "ai": {"kind": "ranged", "range": 20.0}},
		{"name": "Agulhas de Sangue", "cost": 22.0, "cd": 5.0, "icon": "needles", "ai": {"kind": "ranged", "range": 12.0}},
		{"name": "Runa do Vento", "cost": 20.0, "cd": 5.0, "icon": "windrune", "ai": {"kind": "aoe", "range": 3.5}}]

func awaken_name() -> String:
	return "TEIA CARMESIM"

func ult_info() -> Dictionary:
	return {"name": "REDE DA LUA", "col": BLOOD, "rush": "Sword_Dash", "icon": "calista_ult"}

func win_anim() -> String:
	return "Idle_FoldArms"

func trail_bone(_m: Dictionary) -> String:
	return "hand_l"

func dmg_mul() -> float:
	return 1.25 if P.awakened else 1.0

func dodge_fx() -> void:
	Game.fx.afterimage(P, Color(1.0, 0.3, 0.4), 0.3)
	Game.fx.burst("wind", P.global_position + Vector3(0, 0.6, 0), {"n": 6})

func modify_hit(_target, o: Dictionary, _m: Dictionary, h: Dictionary) -> Dictionary:
	o["spark"] = Color(1.0, 0.75, 0.8)
	o["spark2"] = Color(0.8, 0.05, 0.15)
	if h.get("thread", false):
		o["thread"] = true
	return o

func on_hit_dealt(target, _amount: float, o: Dictionary) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	var root_t: float = float(o.get("root", 0.0))
	if o.get("thread", false):
		root_t = maxf(root_t, 0.5)
	if P.awakened:
		root_t = maxf(root_t, 0.35)
	if root_t > 0.0:
		_bind(target, root_t)

## Amarra o alvo com fios de sangue presos ao chão.
func _bind(t, dur: float) -> void:
	t.apply_status("root", dur)
	for k in 3:
		var a := randf() * TAU
		var anchor: Vector3 = t.global_position + Vector3(cos(a) * 1.4, 0.02, sin(a) * 1.4)
		Game.fx.tether(t, anchor, BLOOD, dur, 0.012)

# ---------------------------------------------------------------------
#  Tiros
# ---------------------------------------------------------------------
func fire_hit(m: Dictionary, h: Dictionary) -> void:
	var tgt = P.auto_target(float(h.get("range", 20.0)))
	if tgt:
		P.snap_face(tgt.global_position)
	if String(h.get("kind", "arrow")) == "rain":
		_rain(tgt, float(h.dmg))
		return
	var n: int = int(h.get("fan", 1))
	var start: Vector3 = P.global_position + Vector3(0, 1.35, 0) + P.forward() * 0.6
	var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt else P.forward()
	Audio.sfx("arrow", 0.8)
	for k in n:
		var a := (k - (n - 1) * 0.5) * 0.14
		var root_t: float = float(h.get("root", 0.0))
		proj({"kind": "arrow", "pos": start, "vel": dir.rotated(Vector3.UP, a) * float(h.get("speed", 40.0)), "dmg": float(h.dmg) * P.dmg_mul(),
			"radius": 0.4 if h.get("big", false) else 0.32, "life": 1.0, "knock": 6.0 if h.get("big", false) else 1.5, "heavy": String(m.type) != "light",
			"pierce": h.get("pierce", false), "color": BLOOD, "glow": true, "target": tgt, "homing": float(h.get("homing", 2.0)) if n == 1 else 0.6, "fury_gain": 2.5,
			"trail": func(p, _dt): if randf() < 0.5: Game.fx.burst("magic", p.pos, {"n": 1, "color": BLOOD, "speed": 0.1}),
			"on_hit": func(_p, t, ok): if ok and is_instance_valid(t): on_hit_dealt(t, 0.0, {"root": root_t})})

func _rain(tgt, dmg: float) -> void:
	var c: Vector3 = tgt.global_position if tgt else P.global_position + P.forward() * 8.0
	Game.fx.beam(P.global_position + Vector3(0, 1.5, 0), P.global_position + Vector3(0, 20, 0), {"color": BLOOD, "width": 0.04, "life": 0.3})
	Audio.sfx("arrow")
	for k in 8:
		Game.after(0.25 + k * 0.05, func():
			var p := c + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
			Game.fx.beam(p + Vector3(0, 12, 0), p, {"color": BLOOD, "width": 0.025, "life": 0.15})
			Game.fx.burst("spark", p + Vector3(0, 0.2, 0), {"n": 4, "color": Color(1, 0.6, 0.65)}))
	area({"pos": c, "radius": 2.2, "dmg": dmg * P.dmg_mul(), "delay": 0.4, "knock": 9.0, "heavy": true})

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _thread_arrow(tgt)
		1: _needles(tgt)
		2: _wind_rune()

func _thread_arrow(tgt) -> void:
	cast(0.5, "Pistol_Shoot", 1.0)
	at(0.18, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.35, 0) + P.forward() * 0.6
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("arrow")
		proj({"kind": "arrow", "pos": start, "vel": dir * 44.0, "dmg": 14.0 * P.dmg_mul(), "radius": 0.45, "life": 1.0, "knock": 1.0,
			"color": BLOOD, "glow": true, "target": tgt, "homing": 3.0, "fury_gain": 2.5,
			"trail": func(p, _dt): Game.fx.burst("magic", p.pos, {"n": 2, "color": BLOOD, "speed": 0.1}),
			"on_hit": func(_p, t, ok):
				if ok and is_instance_valid(t):
					_bind(t, 1.4)
					if Game.ui and P.brain == null: Game.ui.toast("FIO CARMESIM", BLOOD, 0.7)}))

func _needles(tgt) -> void:
	cast(0.45, "Spell_Simple_Shoot", 1.3)
	at(0.15, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.3, 0) + P.forward() * 0.5
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("swing")
		Audio.sfx("magic", 0.5)
		for k in 7:
			var a := (k - 3) * 0.09
			proj({"kind": "needle", "pos": start, "vel": dir.rotated(Vector3.UP, a) * 36.0, "dmg": 6.0 * P.dmg_mul(), "radius": 0.3, "life": 0.6, "knock": 1.0,
				"fury_gain": 1.0,
				"on_hit": func(_p, t, ok): if ok and is_instance_valid(t): t.apply_status("slow", 1.2, 0.8)}))

func _wind_rune() -> void:
	var c: Vector3 = P.global_position
	Audio.sfx("wind")
	Audio.sfx("magic", 0.6)
	Game.fx.ring(c, {"color": Color(0.9, 0.95, 1.0), "r1": 3.5, "life": 0.4, "intensity": 2.5})
	Game.fx.cracks(c, 1.8, Color(1.0, 0.3, 0.4), 1.5)
	Game.fx.burst("wind", c + Vector3(0, 0.5, 0), {"n": 24, "r": 1.0})
	for e in foes_in(3.6, c):
		var away: Vector3 = e.global_position - c
		away.y = 0
		e.knock += away.normalized() * 14.0
		hit(e, 10.0, {"knock": 2.0, "reaction": "stagger", "from": c})
	# voa para trás impulsionada pelo vento
	P.set_state("cast")
	P.cast_dur = 0.55
	P.cast_move = -14.0
	P.vy = 6.0
	P.iframes = 0.4
	P.rig.play("NinjaJump_Start", {"speed": 1.5, "blend": 0.04})

# ---------------------------------------------------------------------
#  Despertar: Teia Carmesim
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(10.0)
	Audio.sfx("fury", 0.8)
	Game.cam.shake(0.4)
	Game.fx.shockwave(P.global_position, BLOOD, 6.0, {"glow": Color(0.9, 0.1, 0.2), "debris": false})
	for k in 10:
		var a := k / 10.0 * TAU
		Game.fx.tether(P, P.global_position + Vector3(cos(a) * 4.0, 0.05, sin(a) * 4.0), BLOOD, 1.2, 0.012)
	Game.fx.aura_end(P.aura_node)
	P.aura_node = Game.fx.aura(P, Color(0.9, 0.1, 0.2), Color(1.0, 0.7, 0.75), 1.3)
	if Game.ui:
		Game.ui.toast("— TEIA CARMESIM —", BLOOD, 1.6, true)

# ---------------------------------------------------------------------
#  Ultimate: Rede da Lua
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(0.9, 0.1, 0.2), Color(0.85, 0.9, 1.0), 1.8)
	# salta impulsionada pelo vento e dispara para a lua
	P.rig.play("NinjaJump_Start", {"speed": 1.2, "blend": 0.05})
	P.vy = 9.5
	Game.fx.burst("wind", P.global_position + Vector3(0, 0.4, 0), {"n": 20, "r": 0.8})
	Game.cam.shot(CamShots.dutch(CamShots.low_angle(P, T, 1.0, 4.4, 54.0, 1.3), -0.15))
	await U._wait(0.45)
	if U._aborted() or T == null or not is_instance_valid(T): return
	P.rig.play("Pistol_Shoot", {"speed": 0.8, "blend": 0.05})
	Audio.sfx("arrow")
	Game.fx.beam(P.global_position + Vector3(0, 1.5, 0), P.global_position + Vector3(0, 40, 0), {"color": BLOOD, "width": 0.05, "life": 0.5})
	if Game.post:
		Game.post.flash = 0.35
	await U._wait(0.55)
	if U._aborted() or not is_instance_valid(T): return
	# centenas de fios descem e amarram o alvo
	Game.cam.shot(CamShots.orbit(T.global_position, 5.5, 3.2, P.yaw + 2.4, P.yaw + 3.4, 1.8, 1.2, 50.0))
	T.apply_status("root", 2.4)
	for k in 26:
		var a := randf() * TAU
		var top: Vector3 = T.global_position + Vector3(cos(a) * randf_range(1.0, 6.0), 18.0, sin(a) * randf_range(1.0, 6.0))
		Game.after(k * 0.03, func():
			if is_instance_valid(T):
				Game.fx.tether(top, T, BLOOD, 1.6, 0.012))
	for k in 5:
		await U._wait(0.18)
		if U._aborted() or not is_instance_valid(T): return
		U._hit(6.0, {"hitstop": 0.03, "reaction": "flinch"})
	T.vy = 3.5
	await U._wait(0.35)
	if U._aborted() or not is_instance_valid(T): return
	# a flecha final atravessa
	Game.cam.shot(CamShots.crash_zoom(P, T, 1.2))
	await U._wait(0.15)
	Audio.sfx("arrow")
	Audio.sfx("crit")
	Game.fx.beam(P.global_position + Vector3(0, 1.4, 0), T.chest_pos() + (T.chest_pos() - P.global_position).normalized() * 3.0, {"color": Color(1.0, 0.85, 0.9), "width": 0.08, "life": 0.35})
	if Game.post:
		Game.post.impact_frames(0.09, Color(1.0, 0.85, 0.9))
	Game.fx.impact(T.chest_pos(), BLOOD, 4.0)
	Game.fx.burst("blood", T.chest_pos(), {"n": 20})
	U._hit(66.0, {"knock": 13.0, "reaction": "knockback", "hitstop": 0.2, "shake": 0.7, "crit": true})
	Game.slow(0.6, 0.3)
	await U._wait(0.8)
