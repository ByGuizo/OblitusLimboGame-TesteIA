extends FighterKit
## Yuto — o ronin de passagem. Maestria puramente marcial, sem magia: duas katanas, aço frio.
## "Uma pedra imóvel no meio de um rio turbulento"; move-se "como fumaça se desprendendo de uma fogueira".
##  Passiva  Pedra no Rio: janela de aparar maior; aparar com perfeição solta um iaido automático.
##  Habilidades: Iaido Relâmpago (atravessa o alvo; o corte chega depois) · Postura da Fumaça
##               (contra-ataque) · Corte em X (onda de lâmina cruzada à distância).
##  Despertar  Duas Lâminas: saca a segunda katana — golpes extras e mais velocidade.
##  Ultimate   Juramento do Ronin.

const STEEL := Color(0.85, 0.9, 1.0)
var stance_t := 0.0
var second: Node3D = null

func stats() -> Dictionary:
	return {"hp": 120.0, "speed": 5.4, "sprint": 8.2, "color": STEEL, "chakra": Color(0.8, 0.85, 0.95),
		"name": "Yuto", "title": "O Ronin de Passagem", "vs_hp": 430.0, "fury_gain": 1.1, "ai_range": 2.0}

func moves() -> Dictionary:
	return {
		"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
		"L1": {"anim": "Sword_Regular_A", "speed": 1.5, "type": "light", "lunge": 5.5,
			"hits": [{"t": 0.13, "dmg": 12.0, "range": 2.6, "arc": 2.0, "knock": 2.0, "reaction": "flinch", "slash": {"roll": -0.2}}],
			"combo": 0.17, "cancel": 0.0, "recover": 0.3, "end": 0.42, "next": {"light": "L2", "heavy": "L1H"}},
		"L2": {"anim": "Sword_Regular_B", "speed": 1.5, "type": "light", "lunge": 5.5,
			"hits": [{"t": 0.19, "dmg": 12.0, "range": 2.6, "arc": 2.0, "knock": 2.0, "reaction": "flinch", "slash": {"roll": 0.75, "flip": true}}],
			"combo": 0.23, "cancel": 0.0, "recover": 0.38, "end": 0.52, "next": {"light": "L3", "heavy": "L2H"}},
		"L3": {"anim": "Sword_Regular_C", "from": 0.3, "speed": 1.6, "type": "light", "lunge": 7.0,
			"hits": [{"t": 0.28, "dmg": 16.0, "range": 2.8, "arc": 1.6, "knock": 4.0, "reaction": "stagger", "slash": {"roll": 1.45, "big": true}}],
			"combo": 0.34, "cancel": 0.0, "recover": 0.55, "end": 0.8, "next": {"light": "L4", "heavy": "L3H"}},
		"L4": {"anim": "Sword_Heavy_Combo", "from": 0.4, "speed": 1.7, "type": "finisher", "lunge": 6.0,
			"hits": [
				{"t": 0.3, "dmg": 10.0, "range": 2.8, "arc": 3.0, "knock": 1.0, "reaction": "flinch", "slash": {"roll": 0.2}},
				{"t": 0.6, "dmg": 10.0, "range": 2.8, "arc": 3.0, "knock": 1.0, "reaction": "flinch", "slash": {"roll": -0.6, "flip": true}},
				{"t": 0.95, "dmg": 28.0, "range": 3.2, "arc": 6.3, "knock": 11.0, "reaction": "knockback", "slash": {"roll": 0.0, "big": true}, "finisher": true}],
			"combo": 99.0, "cancel": 1.0, "recover": 1.15, "end": 1.4, "next": {}},
		# pesado: iaido — saque instantâneo, alto crítico
		"H1": {"anim": "Sword_Attack", "from": 0.25, "speed": 1.7, "type": "heavy", "lunge": 9.0,
			"hits": [{"t": 0.32, "dmg": 26.0, "range": 3.0, "arc": 1.8, "knock": 8.0, "reaction": "knockback", "iaido": true, "slash": {"roll": 0.1, "big": true}}],
			"combo": 0.45, "cancel": 0.4, "recover": 0.62, "end": 0.9, "next": {"light": "L2", "heavy": "L2H"}},
		"L1H": {"anim": "Sword_Regular_C", "from": 0.35, "speed": 1.5, "type": "heavy", "lunge": 9.0,
			"hits": [{"t": 0.25, "dmg": 18.0, "range": 2.8, "arc": 1.6, "knock": 3.0, "launch": 8.0, "reaction": "launch", "slash": {"roll": 1.57, "big": true}}],
			"combo": 0.32, "cancel": 0.3, "recover": 0.55, "end": 0.75, "next": {"light": "L2", "heavy": "L3H"}},
		"L2H": {"anim": "Sword_Heavy_Combo", "from": 2.5, "speed": 1.6, "type": "heavy", "lunge": 3.0,
			"hits": [
				{"t": 0.3, "dmg": 14.0, "range": 3.2, "arc": 6.3, "knock": 3.0, "reaction": "stagger", "slash": {"roll": 0.0, "big": true}},
				{"t": 0.7, "dmg": 16.0, "range": 3.2, "arc": 6.3, "knock": 7.0, "reaction": "knockback", "slash": {"roll": 3.14, "big": true}}],
			"combo": 0.8, "cancel": 0.75, "recover": 0.9, "end": 1.1, "next": {"light": "L3", "heavy": "L3H"}},
		# L L L → P: o corte em X cruzado (como na criatura de sombra com o Darin)
		"L3H": {"anim": "Sword_Attack", "from": 0.15, "speed": 1.3, "type": "finisher", "lunge": 7.0,
			"hits": [{"t": 0.42, "dmg": 36.0, "range": 3.2, "arc": 2.2, "knock": 13.0, "launch": 4.0, "reaction": "knockback", "finisher": true, "xcut": true, "slash": {"roll": 0.78, "big": true}}],
			"combo": 99.0, "cancel": 0.55, "recover": 0.75, "end": 1.05, "next": {}},
		"DASH": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.7, "type": "dash", "lunge": 11.0, "lunge_t": 0.22,
			"hits": [{"t": 0.22, "dmg": 16.0, "range": 2.6, "arc": 2.0, "knock": 6.0, "reaction": "stagger", "slash": {"roll": 1.5, "big": true}}],
			"combo": 0.3, "cancel": 0.28, "recover": 0.55, "end": 0.75, "next": {"light": "L2", "heavy": "L2H"}},
		"CTR": {"anim": "Sword_Attack", "from": 0.3, "speed": 2.0, "type": "counter", "lunge": 9.0,
			"hits": [{"t": 0.27, "dmg": 24.0, "range": 2.8, "arc": 2.4, "knock": 6.0, "reaction": "stagger", "iaido": true, "slash": {"roll": 0.1, "big": true}}],
			"combo": 0.32, "cancel": 0.0, "recover": 0.45, "end": 0.6, "next": {"light": "L3", "heavy": "L2H"}},
	}

func skills() -> Array:
	return [
		{"name": "Iaido Relâmpago", "cost": 20.0, "cd": 4.0, "icon": "iaido", "ai": {"kind": "mobility", "range": 9.0}},
		{"name": "Postura da Fumaça", "cost": 15.0, "cd": 5.0, "icon": "stance", "ai": {"kind": "close", "range": 3.5}},
		{"name": "Corte em X", "cost": 25.0, "cd": 5.0, "icon": "xcut", "ai": {"kind": "ranged", "range": 14.0}}]

func awaken_name() -> String:
	return "DUAS LÂMINAS"

func ult_info() -> Dictionary:
	return {"name": "JURAMENTO DO RONIN", "col": Color(0.9, 0.92, 1.0), "rush": "Sword_Dash", "icon": "yuto_ult"}

func win_anim() -> String:
	return "Sword_Idle"

func trail_col(_m: Dictionary) -> Color:
	return STEEL

func trail_bone(m: Dictionary) -> String:
	if P.awakened and m.get("anim", "") == "Sword_Regular_B":
		return "hand_l"
	return "hand_r"

func anim_mul() -> float:
	return 1.15 if P.awakened else 1.0

func parry_window() -> float:
	return 0.4

func dodge_fx() -> void:
	Game.fx.afterimage(P, Color(0.7, 0.72, 0.8), 0.35)
	Game.fx.burst("smoke", P.global_position + Vector3(0, 0.8, 0), {"n": 6, "r": 0.3})

func modify_hit(_target, o: Dictionary, m: Dictionary, h: Dictionary) -> Dictionary:
	o["spark"] = Color(1, 1, 1)
	o["spark2"] = Color(0.6, 0.7, 0.9)
	if h.get("iaido", false) or randf() < 0.18:
		o["crit"] = true
	if h.get("xcut", false):
		o["xcut"] = true
	return o

func melee_fx(_m: Dictionary, h: Dictionary, pos: Vector3) -> void:
	if h.get("xcut", false):
		var sp: Vector3 = pos + Vector3(0, 1.1, 0) + P.forward() * 0.8
		Game.fx.slash(sp, P.yaw, {"color": STEEL, "intensity": 3.2, "roll": 0.78, "big": true})
		Game.fx.slash(sp, P.yaw, {"color": STEEL, "intensity": 3.2, "roll": -0.78, "big": true})
	if h.get("iaido", false):
		Audio.sfx("swingHeavy", 0.8, 1.3)

func on_hit_dealt(target, amount: float, o: Dictionary) -> void:
	if P.awakened and is_instance_valid(target) and target.alive and amount > 0.0 and not o.get("dual", false):
		# Duas Lâminas: a segunda katana segue a primeira
		var t2 = target
		Game.after(0.09, func():
			if is_instance_valid(t2) and t2.alive and is_instance_valid(P):
				Game.fx.slash(t2.chest_pos(), P.yaw + 0.4, {"color": STEEL, "intensity": 2.4, "roll": randf_range(-1.2, 1.2)})
				Game.damage(P, t2, amount * 0.45, {"knock": 1.0, "reaction": "flinch", "dual": true, "spark": Color(1, 1, 1), "fury_gain": 1.0}))

## Pedra no Rio: aparo perfeito → iaido automático.
func on_parry(src) -> void:
	if src == null or not is_instance_valid(src) or not src.alive:
		return
	Game.after(0.05, func():
		if not is_instance_valid(P) or not P.alive or not is_instance_valid(src): return
		_smoke_step(src, 1.2, false)
		P.rig.play("Sword_Attack", {"speed": 2.2, "from": 0.3, "blend": 0.03})
		Game.fx.slash(src.chest_pos(), P.yaw, {"color": STEEL, "intensity": 3.4, "big": true, "roll": 0.1})
		hit(src, 24.0, {"heavy": true, "knock": 8.0, "reaction": "knockback", "crit": true, "unblockable": true}))

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _iaido(tgt)
		1: _stance()
		2: _xcut(tgt)

## Some numa nuvem de fumaça e reaparece junto do alvo (frente ou costas).
func _smoke_step(t, dist: float, behind: bool) -> void:
	var p: Vector3 = t.global_position + Game.fwd(t.yaw) * (-1.0 if behind else 1.0) * (t.radius + dist)
	if Game.level and Game.level.has_method("clamp_point"):
		p = Game.level.clamp_point(p, P.radius)
	Game.fx.burst("smoke", P.global_position + Vector3(0, 1, 0), {"n": 12, "r": 0.4})
	P.global_position = Vector3(p.x, P.global_position.y, p.z)
	P.snap_face(t.global_position)
	Game.fx.burst("smoke", P.global_position + Vector3(0, 1, 0), {"n": 8, "r": 0.3})

## Iaido Relâmpago: atravessa a linha à frente; quem estiver no caminho é cortado um instante depois.
func _iaido(tgt) -> void:
	if tgt and is_instance_valid(tgt):
		P.snap_face(tgt.global_position)
	var start: Vector3 = P.global_position
	var dir: Vector3 = P.forward()
	var dist := 7.5
	if tgt and is_instance_valid(tgt):
		dist = clampf(Game.dist2d(start, tgt.global_position) + 2.2, 3.0, 9.0)
	var end: Vector3 = start + dir * dist
	if Game.level and Game.level.has_method("clamp_point"):
		end = Game.level.clamp_point(end, P.radius)
	var victims := []
	for e in Game.enemies_of(P):
		var rel: Vector3 = e.global_position - start
		rel.y = 0
		var along := rel.dot(dir)
		var side := (rel - dir * along).length()
		if along > -0.5 and along < dist + 0.5 and side < 1.4 + e.radius:
			victims.append(e)
	Game.fx.afterimage(P, Color(0.75, 0.78, 0.9), 0.45)
	for k in 4:
		Game.fx.emit("smoke", start.lerp(end, k / 4.0) + Vector3(0, 1.0, 0), Vector3.ZERO, 0.6, 1.0, Color(0.8, 0.8, 0.85, 0.6))
	P.global_position = Vector3(end.x, P.global_position.y, end.z)
	P.iframes = 0.35
	cast(0.55, "Sword_Attack", 1.8, 0.0, 0.6)
	Audio.sfx("dodge")
	Audio.sfx("swingHeavy", 0.6, 1.4)
	Game.fx.beam(start + Vector3(0, 1.1, 0), end + Vector3(0, 1.1, 0), {"color": STEEL, "width": 0.03, "life": 0.25})
	Game.after(0.35, func():
		if not is_instance_valid(P): return
		Audio.sfx("crit", 0.7)
		for e in victims:
			if is_instance_valid(e) and e.alive:
				Game.fx.slash(e.chest_pos(), P.yaw, {"color": STEEL, "intensity": 3.2, "big": true, "roll": randf_range(-0.4, 0.4)})
				hit(e, 28.0, {"heavy": true, "knock": 6.0, "reaction": "stagger", "crit": true}))

## Postura da Fumaça: imóvel; se for atacado, some e corta pelas costas.
func _stance() -> void:
	P.set_state("cast")
	P.cast_dur = 1.2
	P.cast_move = 0.0
	stance_t = 1.2
	P.rig.play("Sword_Block", {"hold": true, "speed": 1.6, "blend": 0.05})
	Game.fx.burst("smoke", P.global_position + Vector3(0, 0.5, 0), {"n": 8, "r": 0.4})
	Audio.sfx("swing", 0.5)

func intercept_hit(src, _amount: float, o: Dictionary) -> bool:
	if stance_t <= 0.0 or P.state != "cast" or o.get("unblockable", false) and o.get("unavoidable", false):
		return false
	stance_t = 0.0
	if src == null or not is_instance_valid(src) or not (src is Actor):
		return true
	if Game.ui:
		Game.ui.toast("CONTRA-ATAQUE", STEEL, 0.9)
	Audio.sfx("parry")
	if Game.post:
		Game.post.impact_frames(0.05, Color(1, 1, 1))
	_smoke_step(src, 1.1, true)
	P.set_state("move")
	P.rig.play("Sword_Attack", {"speed": 2.2, "from": 0.3, "blend": 0.03})
	var s2 = src
	Game.after(0.12, func():
		if is_instance_valid(s2) and s2.alive and is_instance_valid(P):
			Game.fx.slash(s2.chest_pos(), P.yaw, {"color": STEEL, "intensity": 3.4, "big": true})
			hit(s2, 30.0, {"heavy": true, "knock": 9.0, "reaction": "knockback", "crit": true, "unblockable": true}))
	return true

func tick(delta: float) -> void:
	if stance_t > 0.0:
		stance_t -= delta
		if randf() < 0.3:
			Game.fx.emit("smoke", P.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.2), randf_range(-0.4, 0.4)), Vector3(0, 0.3, 0), 0.8, 0.6, Color(0.8, 0.8, 0.85, 0.4))

func _xcut(tgt) -> void:
	cast(0.55, "Sword_Attack", 1.6, 0.0, 0.15)
	at(0.18, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.15, 0) + P.forward() * 0.8
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("swingHeavy")
		Audio.sfx("whoosh", 0.6)
		proj({"kind": "xslash", "pos": start, "vel": dir * 24.0, "dmg": 24.0 * P.dmg_mul(), "radius": 0.9, "life": 0.7, "knock": 6.0, "heavy": true, "pierce": true,
			"color": STEEL, "scale": 1.3, "fury_gain": 2.5,
			"on_hit": func(_p, t, ok):
				if ok and is_instance_valid(t):
					Game.fx.slash(t.chest_pos(), P.yaw, {"color": STEEL, "intensity": 3.0, "roll": 0.78})
					Game.fx.slash(t.chest_pos(), P.yaw, {"color": STEEL, "intensity": 3.0, "roll": -0.78})}))

# ---------------------------------------------------------------------
#  Despertar: Duas Lâminas
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(10.0)
	Audio.sfx("swingHeavy", 1.0, 0.8)
	Audio.sfx("parry", 0.6)
	Game.cam.shake(0.4)
	Game.fx.shockwave(P.global_position, STEEL, 5.0, {"glow": Color(0.6, 0.65, 0.8), "debris": false})
	if second == null or not is_instance_valid(second):
		second = CharFactory._weapon(P.rig, "katana", "hand_l")
		Toon.convert_tree(second, true, 0.6)
	var hip = P.rig.get_meta("katana_hip") if P.rig.has_meta("katana_hip") else null
	if hip and is_instance_valid(hip):
		hip.visible = false
	Game.fx.aura_end(P.aura_node)
	P.aura_node = Game.fx.aura(P, Color(0.75, 0.8, 0.95), Color(1, 1, 1), 0.9)
	if Game.ui:
		Game.ui.toast("— DUAS LÂMINAS —", STEEL, 1.6, true)

func reset() -> void:
	stance_t = 0.0
	awaken_end()

func awaken_end() -> void:
	if second and is_instance_valid(second):
		second.queue_free()
	second = null
	var hip = P.rig.get_meta("katana_hip") if P.rig.has_meta("katana_hip") else null
	if hip and is_instance_valid(hip):
		hip.visible = true

# ---------------------------------------------------------------------
#  Ultimate: Juramento do Ronin — o tempo para; mil cortes de uma vez
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(0.75, 0.8, 0.95), Color(1, 1, 1), 1.2)
	Game.cam.shot(CamShots.closeup(P, 1.25, 0.4, 32.0, 1.2))
	P.rig.play("Sword_Idle", {"speed": 0.6, "blend": 0.1})
	Audio.sfx("bell", 0.5)
	await U._wait(0.8)
	if U._aborted() or T == null or not is_instance_valid(T): return
	# o tempo para: preto e branco
	if Game.post:
		Game.post.desat_target = 1.0
		Game.post.impact_frames(0.06, Color(1, 1, 1))
	var home: Vector3 = P.global_position
	for i in 7:
		if U._aborted() or not is_instance_valid(T): break
		var ang := i * TAU / 7.0 + randf() * 0.3
		U._place_around(ang, 1.4)
		P.rig.play(["Sword_Regular_A", "Sword_Regular_B", "Sword_Attack"][i % 3], {"speed": 2.6, "from": 0.3 if i % 3 == 2 else 0.0, "blend": 0.0})
		Game.fx.afterimage(P, Color(0.9, 0.9, 0.95), 0.9)
		if i % 2 == 0:
			Game.cam.shot(CamShots.dutch(CamShots.around(T, ang + PI * 0.6, 3.0, 1.0 + (i % 3) * 0.6, 46.0, 0.25), 0.22 if i % 2 else -0.22))
		await U._wait(0.1)
	if U._aborted() or not is_instance_valid(T):
		if Game.post: Game.post.desat_target = 0.0
		return
	# volta, de costas, e embainha devagar
	P.global_position = Vector3(home.x, P.global_position.y, home.z)
	P.snap_face(P.global_position + (P.global_position - T.global_position))
	P.rig.play("Sword_Idle", {"speed": 0.5, "blend": 0.1})
	Game.cam.shot(CamShots.low_angle(P, T, 1.0, 4.4, 46.0, 1.6))
	await U._wait(0.9)
	if U._aborted() or not is_instance_valid(T):
		if Game.post: Game.post.desat_target = 0.0
		return
	# clique da bainha — os cortes chegam
	Audio.sfx("parry", 0.8)
	await U._wait(0.15)
	Audio.sfx("crit")
	Audio.sfx("swingHeavy")
	if Game.post:
		Game.post.impact_frames(0.1, Color(1.0, 1.0, 1.0))
		Game.post.desat_target = 0.0
	for k in 12:
		Game.fx.slash(T.chest_pos(), randf() * TAU, {"color": Color(1, 0.25, 0.3) if k % 3 == 0 else STEEL, "intensity": 3.4, "roll": randf_range(-1.6, 1.6), "big": true})
	Game.fx.impact(T.chest_pos(), STEEL, 4.2)
	U._hit(74.0, {"knock": 13.0, "reaction": "knockback", "hitstop": 0.22, "shake": 0.8, "crit": true})
	Game.slow(0.6, 0.3)
	await U._wait(0.8)
