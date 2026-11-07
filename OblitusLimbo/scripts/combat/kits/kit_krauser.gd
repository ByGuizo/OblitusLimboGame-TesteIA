extends FighterKit
## Lorde Krauser — o verdadeiro Quinto Presságio, híbrido humano-Draconato.
## Sigilo: Tentáculos do Abismo (quatro tentáculos negros que rompem a armadura pelas costas).
## Armadura Arcana: Frio Absoluto — chamas azuis que consomem a existência e anulam o gelo.
## Fogo de dragão (incinerou o próprio pai). O cristal vermelho que desenterra memórias.
##  Estilo   pesado e lento, alcance longo; superarmadura nos golpes pesados.
##  Habilidades: Tentáculos do Abismo (brotam do chão em linha) · Sopro Draconato (cone de fogo) ·
##               Cristal Rubro (atordoa e drena chakra).
##  Despertar  Frio Absoluto: imune a gelo e congelamento; chamas azuis queimam quem encosta.
##  Ultimate   Oblitus Limbo.

const ABYSS := Color(0.7, 0.3, 1.0)
const BLUE := Color(0.35, 0.55, 1.0)
var tentacles: Array = []
var _burn_t := 0.0

func stats() -> Dictionary:
	return {"hp": 200.0, "speed": 4.6, "sprint": 7.0, "color": ABYSS, "chakra": Color(0.6, 0.2, 0.9), "radius": 0.42,
		"name": "Lorde Krauser", "title": "O Quinto Presságio", "vs_hp": 540.0, "fury_gain": 1.0, "ai_range": 2.6}

func moves() -> Dictionary:
	return {
		"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
		"L1": {"anim": "Melee_Hook", "speed": 1.1, "type": "light", "lunge": 5.0,
			"hits": [{"t": 0.2, "dmg": 13.0, "range": 2.4, "arc": 2.0, "knock": 2.0, "reaction": "flinch"}],
			"combo": 0.24, "cancel": 0.0, "recover": 0.36, "end": 0.47, "next": {"light": "L2", "heavy": "L1H"}},
		"L2": {"anim": "Punch_Cross", "speed": 1.5, "type": "light", "lunge": 5.0,
			"hits": [{"t": 0.26, "dmg": 13.0, "range": 2.4, "arc": 2.0, "knock": 2.5, "reaction": "flinch"}],
			"combo": 0.3, "cancel": 0.0, "recover": 0.48, "end": 0.7, "next": {"light": "L3", "heavy": "L2H"}},
		# chicotada de tentáculo (alcance longo)
		"L3": {"anim": "Shield_OneShot", "speed": 1.3, "type": "light", "lunge": 2.0,
			"hits": [{"t": 0.3, "dmg": 16.0, "range": 4.6, "arc": 1.4, "knock": 4.0, "reaction": "stagger", "lash": 1}],
			"combo": 0.4, "cancel": 0.0, "recover": 0.55, "end": 0.8, "next": {"light": "L4", "heavy": "L3H"}},
		# os quatro tentáculos esmagam em volta
		"L4": {"anim": "Idle_Shield_Break", "speed": 1.3, "type": "finisher", "lunge": 0.0,
			"hits": [{"t": 0.45, "dmg": 30.0, "range": 4.2, "arc": 6.3, "knock": 12.0, "reaction": "knockback", "area": true, "finisher": true, "lash": 4}],
			"combo": 99.0, "cancel": 0.6, "recover": 0.8, "end": 1.05, "next": {}},
		# pesado: estocada de tentáculo à distância
		"H1": {"anim": "Spell_Simple_Shoot", "speed": 0.9, "type": "heavy", "lunge": 0.0,
			"hits": [{"t": 0.3, "dmg": 22.0, "range": 6.2, "arc": 0.9, "knock": 8.0, "reaction": "knockback", "lash": 2}],
			"combo": 0.4, "cancel": 0.38, "recover": 0.5, "end": 0.6, "next": {"light": "L2", "heavy": "L2H"}},
		"L1H": {"anim": "Melee_Hook", "speed": 0.95, "type": "heavy", "lunge": 6.0,
			"hits": [{"t": 0.2, "dmg": 18.0, "range": 2.8, "arc": 1.8, "knock": 2.0, "launch": 8.5, "reaction": "launch", "lash": 1}],
			"combo": 0.24, "cancel": 0.24, "recover": 0.38, "end": 0.47, "next": {"light": "L2", "heavy": "L3H"}},
		# L L → P: varredura de tentáculos em 360°
		"L2H": {"anim": "Shield_OneShot", "speed": 1.1, "type": "heavy", "lunge": 0.0,
			"hits": [{"t": 0.3, "dmg": 22.0, "range": 4.4, "arc": 6.3, "knock": 9.0, "reaction": "knockback", "area": true, "lash": 4}],
			"combo": 0.45, "cancel": 0.4, "recover": 0.6, "end": 0.83, "next": {"light": "L3", "heavy": "L3H"}},
		# L L L → P: golpe de cima dos tentáculos (finalizador)
		"L3H": {"anim": "OverhandThrow", "speed": 1.2, "type": "finisher", "lunge": 2.0,
			"hits": [{"t": 0.55, "dmg": 36.0, "range": 5.0, "arc": 1.6, "knock": 13.0, "launch": 4.0, "reaction": "knockback", "finisher": true, "lash": 4}],
			"combo": 99.0, "cancel": 0.7, "recover": 0.9, "end": 1.15, "next": {}},
		"DASH": {"anim": "Shield_Dash", "from": 0.1, "speed": 1.5, "type": "dash", "lunge": 11.0, "lunge_t": 0.22,
			"hits": [{"t": 0.22, "dmg": 18.0, "range": 2.8, "arc": 2.0, "knock": 7.0, "reaction": "stagger"}],
			"combo": 0.3, "cancel": 0.28, "recover": 0.5, "end": 0.75, "next": {"light": "L2", "heavy": "L2H"}},
		"CTR": {"anim": "Melee_Hook", "speed": 1.3, "type": "counter", "lunge": 8.0,
			"hits": [{"t": 0.2, "dmg": 24.0, "range": 3.4, "arc": 2.2, "knock": 7.0, "reaction": "stagger", "lash": 1}],
			"combo": 0.26, "cancel": 0.0, "recover": 0.38, "end": 0.47, "next": {"light": "L3", "heavy": "L2H"}},
	}

func skills() -> Array:
	return [
		{"name": "Tentáculos do Abismo", "cost": 20.0, "cd": 3.5, "icon": "tentacles", "ai": {"kind": "ranged", "range": 10.0}},
		{"name": "Sopro Draconato", "cost": 30.0, "cd": 6.0, "icon": "breath", "ai": {"kind": "aoe", "range": 7.0}},
		{"name": "Cristal Rubro", "cost": 25.0, "cd": 8.0, "icon": "redcrystal", "ai": {"kind": "ranged", "range": 14.0}}]

func awaken_name() -> String:
	return "FRIO ABSOLUTO"

func ult_info() -> Dictionary:
	return {"name": "OBLITUS LIMBO", "col": ABYSS, "rush": "Shield_Dash", "icon": "krauser_ult"}

func win_anim() -> String:
	return "Idle_Shield_Break"

func trail_col(_m: Dictionary) -> Color:
	return BLUE if P.awakened else ABYSS

func super_armor() -> bool:
	return P.state == "attack" and String(P.cur_move.get("type", "")) in ["heavy", "finisher"]

func incoming_mul(_src, o: Dictionary) -> float:
	if P.awakened and String(o.get("element", "")) == "ice":
		return 0.3
	return 1.0

func dodge_fx() -> void:
	Game.fx.afterimage(P, Color(0.4, 0.15, 0.6), 0.3)
	Game.fx.burst("shadow", P.global_position + Vector3(0, 0.8, 0), {"n": 10, "r": 0.3})

# ---------------------------------------------------------------------
#  Tentáculos nas costas
# ---------------------------------------------------------------------
func setup() -> void:
	tentacles = [Krauser.Tentacle.new(Game.world, -1.0, 1.0), Krauser.Tentacle.new(Game.world, 1.0, 1.0),
		Krauser.Tentacle.new(Game.world, -1.0, -0.3), Krauser.Tentacle.new(Game.world, 1.0, -0.3)]

func cleanup() -> void:
	for t in tentacles:
		t.free_all()
	tentacles.clear()

func tick(delta: float) -> void:
	var back: Vector3 = -P.forward()
	var right := Vector3(-cos(P.yaw), 0, sin(P.yaw))
	var base: Vector3 = P.chest_pos() + back * 0.25
	for tc in tentacles:
		tc.set_visible(P.visible and P.alive)
		tc.update(Game.time, base, back, right)
	if P.awakened:
		if randf() < 0.9:
			Game.fx.burst("fire", P.global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 2.0), randf_range(-0.5, 0.5)), {"n": 1, "color": Color(0.82, 0.9, 1.0), "color2": Color(0.06, 0.2, 1.0), "size": 0.9, "r": 0.05})
		_burn_t -= delta
		if _burn_t <= 0.0:
			_burn_t = 0.35
			for e in foes_in(2.2):
				hit(e, 4.0, {"knock": 0.5, "fx": false, "element": "fire", "num_col": Color(0.5, 0.7, 1.0)})

## Estica `n` tentáculos até um ponto (golpe).
func lash(p: Vector3, n := 1) -> void:
	Audio.sfx("tentacle", 0.8)
	for k in mini(n, tentacles.size()):
		var tc = tentacles[(k + randi()) % tentacles.size()]
		tc.target = p + Vector3(randf_range(-0.4, 0.4), 0.2 + k * 0.15, randf_range(-0.4, 0.4))
		var tw: Tween = P.create_tween()
		tw.tween_property(tc, "extend", 1.0, 0.12)
		tw.tween_interval(0.12)
		tw.tween_property(tc, "extend", 0.0, 0.3)
		tw.tween_callback(func(): tc.target = null)

func melee_fx(_m: Dictionary, h: Dictionary, pos: Vector3) -> void:
	var n: int = int(h.get("lash", 0))
	if n <= 0:
		return
	var tgt = P.lock_target if P.lock_target and is_instance_valid(P.lock_target) else P.auto_target(float(h.range))
	var p: Vector3 = tgt.chest_pos() if tgt and Game.dist2d(tgt.global_position, pos) < float(h.range) + 1.0 else pos + P.forward() * float(h.range) * 0.8 + Vector3(0, 1.0, 0)
	if h.get("area", false):
		for k in 4:
			var a: float = P.yaw + k * PI * 0.5 + 0.4
			lash(pos + Vector3(sin(a), 0, cos(a)) * float(h.range) * 0.8 + Vector3(0, 0.3, 0), 1)
		Game.fx.burst("shadow", pos + Vector3(0, 0.5, 0), {"n": 20, "r": 1.5})
	else:
		lash(p, n)
		Game.fx.burst("shadow", p, {"n": 8, "r": 0.4})

func modify_hit(_target, o: Dictionary, _m: Dictionary, _h: Dictionary) -> Dictionary:
	o["spark"] = Color(0.8, 0.6, 1.0) if not P.awakened else Color(0.8, 0.9, 1.0)
	o["spark2"] = Color(0.3, 0.05, 0.4) if not P.awakened else Color(0.1, 0.3, 1.0)
	return o

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _tentacle_line(tgt)
		1: _breath(tgt)
		2: _crystal(tgt)

func _tentacle_line(tgt) -> void:
	cast(0.7, "Spell_Simple_Shoot", 0.9)
	var dir: Vector3 = dir_to(tgt)
	var start: Vector3 = P.global_position
	Audio.sfx("tentacle")
	for k in 4:
		var p: Vector3 = start + dir * (2.0 + k * 2.1)
		p.y = start.y
		Game.after(0.25 + k * 0.12, func():
			if not is_instance_valid(P): return
			Game.fx.ground_tentacle(p, 2.8, 0.9, dir * 0.6)
			Audio.sfx("tentacle", 0.6)
			for e in foes_in(1.4, p):
				hit(e, 15.0, {"knock": 2.0, "launch": 6.0, "reaction": "launch", "from": p}))

func _breath(tgt) -> void:
	if tgt and is_instance_valid(tgt):
		P.snap_face(tgt.global_position)
	P.set_state("cast")
	P.cast_dur = 1.5
	P.cast_move = 0.0
	P.rig.play("Idle_Shield_Break", {"speed": 1.0, "blend": 0.05})
	Audio.sfx("roar", 0.6)
	Audio.sfx("fire")
	var y: float = P.yaw
	var blue: bool = P.awakened
	var ticks := [0]
	Game.fx.custom(1.2, func(tt, _dt):
		if not is_instance_valid(P) or P.state != "cast": return
		var mouth: Vector3 = P.head_pos(-0.15) + Game.fwd(y) * 0.3
		Game.fx.breath_puff(mouth, y, blue)
		if tt > ticks[0] * 0.2:
			ticks[0] += 1
			for e in Game.enemies_of(P):
				var d := Game.dist2d(e.global_position, P.global_position)
				if d < 7.5 and abs(Game.ang_diff(Game.yaw_to(P.global_position, e.global_position), y)) < 0.5:
					hit(e, 5.5, {"knock": 1.5, "fx": false, "vol": 0.5, "element": "fire", "num_col": Color(0.5, 0.7, 1.0) if blue else Color(1, 0.6, 0.3)}))

func _crystal(tgt) -> void:
	cast(0.55, "Spell_Simple_Shoot", 1.1)
	at(0.2, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.4, 0) + P.forward() * 0.6
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("magic")
		proj({"kind": "crystal", "pos": start, "vel": dir * 22.0, "dmg": 12.0 * P.dmg_mul(), "radius": 0.5, "life": 1.2, "knock": 1.0,
			"target": tgt, "homing": 2.5, "fury_gain": 2.0,
			"trail": func(p, _dt): Game.fx.burst("magic", p.pos, {"n": 1, "color": Color(1, 0.1, 0.2), "speed": 0.2}),
			"on_hit": func(_p, t, ok):
				if not ok or not is_instance_valid(t): return
				# memórias desenterradas à força: atordoa e drena chakra
				t.apply_status("root", 1.2)
				if t is Player:
					t.energy = maxf(0.0, t.energy - 30.0)
					t.cur_move = {}
					t.set_state("hit")
					t.state_lock = 1.2
					t.rig.play("Hit_Head", {"speed": 0.5})
					if t.brain == null and Game.post:
						Game.post.impact_frames(0.06, Color(1.0, 0.6, 0.65))
				elif t.has_method("stun"):
					t.stun(1.2)
				Game.fx.burst("magic", t.chest_pos(), {"n": 24, "color": Color(1, 0.15, 0.25)})
				if Game.ui: Game.ui.toast("MEMÓRIAS...", Color(1, 0.35, 0.4), 0.9)}))

# ---------------------------------------------------------------------
#  Despertar: Armadura Arcana — Frio Absoluto
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(10.0)
	P.freeze_immune = true
	P.frost = 0.0
	P.break_freeze()
	Audio.sfx("reveal", 0.8)
	Audio.sfx("fire")
	Game.cam.shake(0.5)
	Game.fx.shockwave(P.global_position, BLUE, 7.0, {"glow": Color(0.1, 0.3, 1.0), "debris": false})
	Game.fx.burst("fire", P.global_position + Vector3(0, 1, 0), {"n": 50, "r": 0.8, "color": Color(0.85, 0.92, 1.0), "color2": Color(0.06, 0.25, 1.0), "size": 1.4, "up": 2.0})
	Game.fx.aura_end(P.aura_node)
	P.aura_node = Game.fx.aura(P, Color(0.2, 0.4, 1.0), Color(0.85, 0.92, 1.0), 1.6)
	if Game.ui:
		var vs_viktor: bool = P.opponent != null and is_instance_valid(P.opponent) and P.opponent.kit == "viktor"
		Game.ui.bark("krauser", "Você não pode congelar o que já é o próprio zero!" if vs_viktor else "Armadura Arcana: Frio Absoluto!", 2.4)
		Game.ui.toast("— FRIO ABSOLUTO —", BLUE, 1.6, true)

func awaken_end() -> void:
	P.freeze_immune = false

# ---------------------------------------------------------------------
#  Ultimate: Oblitus Limbo
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(0.5, 0.1, 0.8), Color(1.0, 0.2, 0.4), 1.8)
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 2.4, -0.7, 40.0, 2.0, -0.15), 0.18))
	P.rig.play("Spell_Simple_Idle", {"loop": true, "blend": 0.1})
	if Game.ui:
		Game.ui.bark("krauser", "Sanguis pro limine, anima pro vana... Aperi portam limbi... OBLITUS LIMBO!", 2.6)
	Audio.sfx("roar", 0.8)
	Audio.sfx("portal")
	await U._wait(1.4)
	if U._aborted() or T == null or not is_instance_valid(T): return
	# o portal se abre e arrasta o alvo para o Limbo
	var c: Vector3 = T.global_position
	Game.fx.ring(c + Vector3(0, 0.1, 0), {"color": Color(0.7, 0.15, 1.0), "r1": 4.0, "life": 2.2, "intensity": 3.0})
	Game.fx.cracks(c, 3.4, Color(0.7, 0.15, 1.0), 4.0)
	Game.cam.shot(CamShots.orbit(c, 6.0, 3.0, P.yaw + 2.6, P.yaw + 3.6, 2.4, 0.8, 56.0))
	if Game.post:
		Game.post.speed_target = 0.7
		Game.post.flash = 0.3
	for k in 30:
		var a := randf() * TAU
		Game.fx.emit("shadow", c + Vector3(cos(a) * 5.0, randf_range(0.2, 2.5), sin(a) * 5.0), (Vector3(-cos(a), 0, -sin(a)) * 6.0), 0.8, 0.9, Color(0.3, 0.05, 0.4))
	T.vy = 4.0
	await U._wait(0.6)
	if U._aborted() or not is_instance_valid(T): return
	if Game.post:
		Game.post.impact_frames(0.08, Color(0.9, 0.7, 1.0))
	# dentro do Limbo: tentáculos de todos os lados
	for k in 6:
		if U._aborted() or not is_instance_valid(T): break
		var a := k / 6.0 * TAU
		var p: Vector3 = T.global_position + Vector3(cos(a), 0, sin(a)) * 1.6
		p.y = c.y
		Game.fx.ground_tentacle(p, 3.0, 0.8, (T.global_position - p).normalized() * 0.8)
		Audio.sfx("tentacle", 0.7)
		U._hit(9.0, {"hitstop": 0.04, "reaction": "stagger"})
		await U._wait(0.14)
	if U._aborted() or not is_instance_valid(T):
		if Game.post: Game.post.speed_target = 0.0
		return
	Game.cam.shot(CamShots.crash_zoom(P, T, 1.3))
	for k in 4:
		var a := k / 4.0 * TAU + 0.4
		Game.fx.ground_tentacle(T.global_position + Vector3(cos(a), 0, sin(a)) * 0.8, 4.0, 1.0, Vector3.ZERO)
	await U._wait(0.2)
	Audio.sfx("explosion")
	Audio.sfx("crit")
	if Game.post:
		Game.post.speed_target = 0.0
		Game.post.impact_frames(0.1, Color(0.95, 0.75, 1.0))
		Game.post.flash = 0.4
	Game.fx.shockwave(T.global_position, ABYSS, 8.0, {"glow": Color(0.6, 0.1, 1.0)})
	Game.fx.impact(T.chest_pos(), ABYSS, 4.2)
	Game.fx.burst("shadow", T.chest_pos(), {"n": 60, "r": 1.0, "speed": 3.0, "size": 1.5})
	U._hit(66.0, {"knock": 14.0, "reaction": "knockback", "hitstop": 0.2, "shake": 0.9, "crit": true})
	Game.slow(0.6, 0.3)
	await U._wait(0.8)
