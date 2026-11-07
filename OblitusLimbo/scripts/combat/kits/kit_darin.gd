extends FighterKit
## Darin Leafheart — o druida dos lobos. Sigilo Autoformado: Instinto de Caça
## (aura verde-esmeralda, manoplas translúcidas em forma de garras de lobo, rosnado espiritual).
##  Passiva  Fúria Selvagem: cada acerto acumula (até 10) e o deixa mais rápido.
##  Combo    garras erráticas e imprevisíveis, avanços em zigue-zague.
##  Habilidades: Manifestar Chicotes! (puxa o alvo) · Matilha Espiritual (lobos verdes) ·
##               Salto Predador (bote sobre o alvo).
##  Despertar  Instinto de Caça: garras gigantes e o "borrão verde e letal".
##  Ultimate   Caçada da Matilha.

const GREEN := Color(0.3, 1.0, 0.5)
var stacks := 0
var stack_t := 0.0
var claws: Array = []
var _blur_t := 0.0

func stats() -> Dictionary:
	return {"hp": 120.0, "speed": 5.3, "sprint": 8.1, "color": GREEN, "chakra": Color(0.3, 0.95, 0.5),
		"name": "Darin Leafheart", "title": "O Druida dos Lobos", "vs_hp": 440.0, "fury_gain": 1.1, "ai_range": 1.7}

func moves() -> Dictionary:
	return {
		"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
		"L1": {"anim": "Punch_Jab", "speed": 1.8, "type": "light", "lunge": 6.0,
			"hits": [{"t": 0.2, "dmg": 10.0, "range": 2.3, "arc": 2.0, "knock": 2.0, "reaction": "flinch", "claw": true}],
			"combo": 0.22, "cancel": 0.0, "recover": 0.36, "end": 0.52, "next": {"light": "L2", "heavy": "L1H"}},
		"L2": {"anim": "Punch_Cross", "speed": 1.8, "type": "light", "lunge": 6.0, "zig": 1.0,
			"hits": [{"t": 0.26, "dmg": 10.0, "range": 2.3, "arc": 2.0, "knock": 2.0, "reaction": "flinch", "claw": true}],
			"combo": 0.28, "cancel": 0.0, "recover": 0.42, "end": 0.6, "next": {"light": "L3", "heavy": "L2H"}},
		# arranhões em sequência (dois cortes)
		"L3": {"anim": "Zombie_Scratch", "from": 0.25, "speed": 2.3, "type": "light", "lunge": 7.0, "zig": -1.0,
			"hits": [{"t": 0.25, "dmg": 8.0, "range": 2.4, "arc": 2.4, "knock": 1.0, "reaction": "flinch", "claw": true},
				{"t": 0.65, "dmg": 10.0, "range": 2.4, "arc": 2.4, "knock": 3.0, "reaction": "stagger", "claw": true}],
			"combo": 0.7, "cancel": 0.0, "recover": 0.85, "end": 1.05, "next": {"light": "L4", "heavy": "L3H"}},
		# bote final com as duas garras
		"L4": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.8, "type": "finisher", "lunge": 12.0, "lunge_t": 0.22,
			"hits": [{"t": 0.22, "dmg": 26.0, "range": 2.9, "arc": 2.6, "knock": 11.0, "reaction": "knockback", "claw": true, "finisher": true}],
			"combo": 99.0, "cancel": 0.3, "recover": 0.5, "end": 0.75, "next": {}},
		"H1": {"anim": "Zombie_Scratch", "from": 0.3, "speed": 1.6, "type": "heavy", "lunge": 7.0,
			"hits": [{"t": 0.65, "dmg": 24.0, "range": 2.8, "arc": 2.6, "knock": 8.0, "reaction": "knockback", "claw": true}],
			"combo": 0.72, "cancel": 0.6, "recover": 0.9, "end": 1.1, "next": {"light": "L2", "heavy": "L2H"}},
		# L → P: gancho ascendente que lança
		"L1H": {"anim": "Melee_Hook", "speed": 1.0, "type": "heavy", "lunge": 7.0,
			"hits": [{"t": 0.2, "dmg": 18.0, "range": 2.5, "arc": 1.8, "knock": 2.0, "launch": 8.0, "reaction": "launch", "claw": true}],
			"combo": 0.24, "cancel": 0.24, "recover": 0.38, "end": 0.47, "next": {"light": "L2", "heavy": "L3H"}},
		# L L → P: giro com as garras (área)
		"L2H": {"anim": "Shield_OneShot", "speed": 1.3, "type": "heavy", "lunge": 3.0,
			"hits": [{"t": 0.3, "dmg": 20.0, "range": 3.2, "arc": 6.3, "knock": 7.0, "reaction": "stagger", "area": true, "claw": true}],
			"combo": 0.4, "cancel": 0.36, "recover": 0.55, "end": 0.8, "next": {"light": "L3", "heavy": "L3H"}},
		# L L L → P: salto e queda com as garras (finalizador)
		"L3H": {"anim": "NinjaJump_Land", "speed": 1.2, "type": "finisher", "lunge": 5.0, "jump": 7.0,
			"hits": [{"t": 0.32, "dmg": 32.0, "range": 3.4, "arc": 6.3, "knock": 12.0, "launch": 4.0, "reaction": "knockback", "area": true, "finisher": true, "claw": true}],
			"combo": 99.0, "cancel": 0.45, "recover": 0.7, "end": 1.0, "next": {}},
		"DASH": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.8, "type": "dash", "lunge": 12.0, "lunge_t": 0.22,
			"hits": [{"t": 0.22, "dmg": 15.0, "range": 2.6, "arc": 2.0, "knock": 6.0, "reaction": "stagger", "claw": true}],
			"combo": 0.3, "cancel": 0.28, "recover": 0.5, "end": 0.75, "next": {"light": "L3", "heavy": "L2H"}},
		"CTR": {"anim": "Punch_Cross", "speed": 2.0, "type": "counter", "lunge": 9.0,
			"hits": [{"t": 0.26, "dmg": 20.0, "range": 2.6, "arc": 2.2, "knock": 6.0, "reaction": "stagger", "claw": true}],
			"combo": 0.3, "cancel": 0.0, "recover": 0.45, "end": 0.65, "next": {"light": "L3", "heavy": "L2H"}},
	}

func skills() -> Array:
	return [
		{"name": "Manifestar Chicotes!", "cost": 15.0, "cd": 3.0, "icon": "vines", "ai": {"kind": "ranged", "range": 10.0}},
		{"name": "Matilha Espiritual", "cost": 30.0, "cd": 7.0, "icon": "pack", "ai": {"kind": "ranged", "range": 14.0}},
		{"name": "Salto Predador", "cost": 20.0, "cd": 4.0, "icon": "pounce", "ai": {"kind": "mobility", "range": 12.0, "need_target": true}}]

func awaken_name() -> String:
	return "INSTINTO DE CAÇA"

func ult_info() -> Dictionary:
	return {"name": "CAÇADA DA MATILHA", "col": GREEN, "rush": "Sword_Dash", "icon": "darin_ult"}

func win_anim() -> String:
	return "Yes"

func trail_col(_m: Dictionary) -> Color:
	return Color(0.4, 1.2, 0.6) if P.awakened else GREEN

func trail_bone(m: Dictionary) -> String:
	return "hand_l" if m.get("anim", "") == "Punch_Jab" else "hand_r"

func dmg_mul() -> float:
	return (1.35 if P.awakened else 1.0) * (1.0 + stacks * 0.02)

func move_mul() -> float:
	return (1.25 if P.awakened else 1.0) * (1.0 + stacks * 0.03)

func anim_mul() -> float:
	return 1.0 + stacks * 0.025 + (0.12 if P.awakened else 0.0)

func dodge_fx() -> void:
	Game.fx.afterimage(P, GREEN, 0.35)

# ---------------------------------------------------------------------
#  Garras espirituais
# ---------------------------------------------------------------------
func setup() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 1.4, 0.55, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in ["l", "r"]:
		var root := Node3D.new()
		for k in 3:
			var m := MeshInstance3D.new()
			var pm := PrismMesh.new(); pm.size = Vector3(0.03, 0.2, 0.02)
			m.mesh = pm
			m.material_override = mat
			m.position = Vector3((k - 1) * 0.035, 0.12, 0.03)
			m.rotation.x = 0.35
			root.add_child(m)
		var hb: Vector3 = P.rig.skel.get_bone_global_rest(P.rig.skel.find_bone("hand_" + side)).origin
		P.rig.attach_model(root, "hand_" + side, Transform3D(Basis(), hb))
		root.scale = Vector3.ONE * 0.7
		claws.append(root)

func reset() -> void:
	stacks = 0
	stack_t = 0.0
	_claw_scale(0.7)

func _claw_scale(s: float) -> void:
	for c in claws:
		if is_instance_valid(c):
			c.scale = Vector3.ONE * s

# ---------------------------------------------------------------------
#  Passiva: Fúria Selvagem + zigue-zague
# ---------------------------------------------------------------------
func on_attack_start(m: Dictionary) -> void:
	# avanços imprevisíveis: desvio lateral no início de alguns golpes
	var z: float = float(m.get("zig", 0.0))
	if z != 0.0 or (P.awakened and randf() < 0.5):
		if z == 0.0:
			z = 1.0 if randf() < 0.5 else -1.0
		var right := Vector3(-cos(P.yaw), 0, sin(P.yaw))
		P.knock += right * z * 6.0
		Game.fx.afterimage(P, GREEN, 0.25)

func modify_hit(_target, o: Dictionary, _m: Dictionary, _h: Dictionary) -> Dictionary:
	o["spark"] = Color(0.75, 1.0, 0.8)
	o["spark2"] = Color(0.1, 0.8, 0.3)
	return o

func melee_fx(_m: Dictionary, h: Dictionary, pos: Vector3) -> void:
	if h.get("claw", false):
		var sp: Vector3 = pos + Vector3(0, 1.1, 0) + P.forward() * 0.7
		for k in 3:
			Game.fx.slash(sp + Vector3(0, (k - 1) * 0.12, 0), P.yaw, {"color": GREEN, "intensity": 2.6, "roll": randf_range(-0.9, -0.5) if randi() % 2 else randf_range(0.5, 0.9), "scale": 0.7 if not P.awakened else 1.2})

func on_hit_dealt(_target, _amount: float, _o: Dictionary) -> void:
	stacks = mini(10, stacks + 1)
	stack_t = 3.0

func tick(delta: float) -> void:
	stack_t -= delta
	if stack_t <= 0.0 and stacks > 0:
		stack_t = 0.6
		stacks -= 1
	if stacks >= 6 and randf() < 0.2:
		Game.fx.burst("magic", P.global_position + Vector3(0, randf_range(0.3, 1.5), 0), {"n": 1, "color": GREEN, "speed": 0.3})
	if P.awakened:
		_blur_t -= delta
		if _blur_t <= 0.0 and P.speed > 3.0:
			_blur_t = 0.12
			Game.fx.afterimage(P, GREEN, 0.25)

# ---------------------------------------------------------------------
#  Habilidades
# ---------------------------------------------------------------------
func use_skill(i: int, tgt) -> void:
	match i:
		0: _vines(tgt)
		1: _pack(tgt)
		2: _pounce(tgt)

func _vines(tgt) -> void:
	cast(0.45, "Spell_Simple_Shoot", 1.3)
	say("Manifestar chicotes!", GREEN, 0.8)
	at(0.15, func():
		var start: Vector3 = P.global_position + Vector3(0, 1.2, 0) + P.forward() * 0.5
		var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt and is_instance_valid(tgt) else P.forward()
		Audio.sfx("whoosh", 0.7)
		proj({"kind": "needle", "pos": start, "vel": dir * 26.0, "dmg": 12.0 * P.dmg_mul(), "radius": 0.5, "life": 0.5, "knock": 0.0, "scale": 2.0,
			"color": GREEN, "fury_gain": 2.0,
			"trail": func(p, _dt): Game.fx.burst("magic", p.pos, {"n": 1, "color": GREEN, "speed": 0.2}),
			"on_hit": func(_p, t, ok):
				if not ok or not is_instance_valid(t): return
				Game.fx.tether(P, t, GREEN, 0.45, 0.035)
				var pull: Vector3 = P.global_position - t.global_position
				pull.y = 0
				t.knock += pull.normalized() * minf(18.0, pull.length() * 3.0)
				t.apply_status("slow", 1.2, 0.6)
				Audio.sfx("hit", 0.6)}))

func _pack(tgt) -> void:
	cast(0.6, "Idle_Shield_Break", 1.6)
	Audio.sfx("roar", 0.7, 1.5)
	at(0.25, func():
		var right := Vector3(-cos(P.yaw), 0, sin(P.yaw))
		for k in 3:
			var off: Vector3 = right * (k - 1) * 1.1
			var start: Vector3 = P.global_position + off + P.forward() * 0.6
			start.y = P.global_position.y + 0.05
			var dir: Vector3 = P.forward()
			if tgt and is_instance_valid(tgt):
				dir = (tgt.global_position - start)
				dir.y = 0
				dir = dir.normalized()
			proj({"kind": "wolf", "pos": start, "vel": dir * 15.0, "dmg": 14.0 * P.dmg_mul(), "radius": 0.75, "life": 1.4, "knock": 4.0, "heavy": true,
				"target": tgt, "homing": 3.0, "fury_gain": 2.0, "scale": 1.15,
				"trail": func(p, _dt):
					p.pos.y = P.global_position.y + 0.05 if is_instance_valid(P) else p.pos.y
					p.vel.y = 0.0
					if randf() < 0.6: Game.fx.burst("magic", p.pos + Vector3(0, 0.5, 0), {"n": 1, "color": GREEN, "speed": 0.3}),
				"on_hit": func(_p, t, ok):
					if ok and is_instance_valid(t):
						Game.fx.slash(t.chest_pos(), randf() * TAU, {"color": GREEN, "intensity": 2.6})
						Audio.sfx("hitHeavy", 0.5)}))

func _pounce(tgt) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	P.set_state("cast")
	P.cast_dur = 0.75
	P.cast_move = 0.0
	P.snap_face(tgt.global_position)
	P.rig.play("NinjaJump_Start", {"speed": 1.6, "blend": 0.04})
	Audio.sfx("roar", 0.5, 1.6)
	P.vy = 7.5
	var from: Vector3 = P.global_position
	var to: Vector3 = tgt.global_position - dir_to(tgt) * 0.9
	Game.fx.custom(0.45, func(t, _dt):
		if not is_instance_valid(P) or P.state != "cast": return
		var k := clampf(t / 0.45, 0.0, 1.0)
		var p := from.lerp(to, k)
		P.global_position = Vector3(p.x, P.global_position.y, p.z)
		if randf() < 0.6: Game.fx.afterimage(P, GREEN, 0.2))
	Game.after(0.47, func():
		if not is_instance_valid(P) or not P.alive: return
		P.rig.play("NinjaJump_Land", {"speed": 1.4, "from": 0.2, "blend": 0.04})
		Game.fx.shockwave(P.global_position, GREEN, 3.0, {"glow": Color(0.2, 0.8, 0.35), "debris": true})
		Game.cam.shake(0.4)
		Audio.sfx("hitHeavy")
		for e in foes_in(2.8):
			hit(e, 22.0, {"heavy": true, "knock": 7.0, "reaction": "knockback", "from": P.global_position})
			Game.fx.slash(e.chest_pos(), P.yaw, {"color": GREEN, "intensity": 3.0, "big": true}))

# ---------------------------------------------------------------------
#  Despertar: Instinto de Caça
# ---------------------------------------------------------------------
func awaken() -> void:
	P.begin_awaken(10.0)
	stacks = 10
	stack_t = 10.0
	Audio.sfx("roar", 1.0, 1.4)
	Audio.sfx("fury", 0.7)
	Game.cam.shake(0.6)
	Game.cam.kick(10.0)
	Game.fx.shockwave(P.global_position, GREEN, 7.0, {"glow": Color(0.2, 0.9, 0.4), "debris": true})
	Game.fx.aura_end(P.aura_node)
	P.aura_node = Game.fx.aura(P, Color(0.15, 0.95, 0.4), Color(0.7, 1.0, 0.75), 1.6)
	_claw_scale(2.4)
	P.rig.set_eye_glow(Color(0.4, 2.0, 0.6))
	if Game.ui:
		Game.ui.toast("— INSTINTO DE CAÇA! —", GREEN, 1.6, true)

func awaken_end() -> void:
	_claw_scale(0.7)
	P.rig.set_eye_glow(Color.BLACK)

# ---------------------------------------------------------------------
#  Ultimate: Caçada da Matilha
# ---------------------------------------------------------------------
func ult_sequence(U) -> void:
	var T = U.tgt
	U._aura = Game.fx.aura(P, Color(0.15, 0.95, 0.4), Color(0.7, 1.0, 0.75), 2.0)
	_claw_scale(2.6)
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 1.3, 0.4, 34.0, 1.2), -0.15))
	P.rig.play("Idle_Shield_Break", {"speed": 1.0, "blend": 0.05})
	Audio.sfx("roar", 1.0, 1.4)
	Game.cam.shake(0.5)
	await U._wait(1.0)
	if U._aborted() or T == null or not is_instance_valid(T): return
	# a matilha vem de todos os lados
	Game.cam.shot(CamShots.orbit(T.global_position, 6.0, 2.4, 0.0, 1.4, 1.8, 1.0, 54.0))
	for k in 6:
		var a := k / 6.0 * TAU
		var start: Vector3 = T.global_position + Vector3(cos(a), 0, sin(a)) * 7.0
		var v: Node3D = Game.fx.projectile_visual("wolf", {"scale": 1.2})
		Game.world.add_child(v)
		v.global_position = start
		var tp: Vector3 = T.global_position
		v.look_at(Vector3(tp.x, start.y, tp.z), Vector3.UP)
		var vr := [v]
		Game.fx.custom(0.5 + k * 0.08, func(t, _dt):
			if not is_instance_valid(vr[0]): return
			vr[0].global_position = start.lerp(Vector3(tp.x, start.y, tp.z), clampf(t / (0.5 + k * 0.08), 0.0, 1.0)), func():
			if is_instance_valid(vr[0]):
				Game.fx.burst("magic", vr[0].global_position + Vector3(0, 0.5, 0), {"n": 10, "color": GREEN})
				vr[0].queue_free())
	for k in 6:
		await U._wait(0.13)
		if U._aborted() or not is_instance_valid(T): return
		Game.fx.slash(T.chest_pos(), randf() * TAU, {"color": GREEN, "intensity": 3.0, "big": true})
		U._hit(7.0, {"hitstop": 0.03, "reaction": "flinch"})
	# o borrão verde
	for i in 3:
		if U._aborted() or not is_instance_valid(T): return
		U._place_around([PI * 0.5, -PI * 0.6, PI][i], 1.3)
		P.rig.play(["Punch_Jab", "Punch_Cross", "Zombie_Scratch"][i], {"speed": 2.4, "from": 0.3 if i == 2 else 0.0, "blend": 0.0})
		Game.fx.afterimage(P, GREEN, 0.5)
		Game.cam.shot(CamShots.dutch(CamShots.around(T, PI * (0.4 + i * 0.6), 2.6, 1.3, 46.0, 0.3), 0.2 if i % 2 else -0.2))
		Game.fx.slash(T.chest_pos(), P.yaw, {"color": GREEN, "intensity": 3.0, "big": true, "roll": randf_range(-1.2, 1.2)})
		U._hit(10.0, {"hitstop": 0.05, "reaction": "stagger"})
		await U._wait(0.22)
	if U._aborted() or not is_instance_valid(T): return
	# garras cruzadas em X
	U._place_around(0.0, 1.4)
	Game.cam.shot(CamShots.crash_zoom(P, T, 1.2))
	P.rig.play("Sword_Dash", {"speed": 1.6, "from": 0.2, "blend": 0.0})
	await U._wait(0.18)
	Audio.sfx("crit")
	Audio.sfx("roar", 0.8, 1.3)
	if Game.post:
		Game.post.impact_frames(0.09, Color(0.85, 1.0, 0.9))
	Game.fx.slash(T.chest_pos(), P.yaw, {"color": GREEN, "intensity": 3.6, "big": true, "roll": 0.78})
	Game.fx.slash(T.chest_pos(), P.yaw, {"color": GREEN, "intensity": 3.6, "big": true, "roll": -0.78})
	Game.fx.impact(T.chest_pos(), GREEN, 4.0)
	Game.fx.shockwave(T.global_position, GREEN, 6.0, {"glow": Color(0.2, 0.9, 0.4)})
	U._hit(60.0, {"knock": 13.0, "reaction": "knockback", "hitstop": 0.2, "shake": 0.8, "crit": true})
	Game.slow(0.6, 0.3)
	await U._wait(0.8)
	if not P.awakened:
		_claw_scale(0.7)
