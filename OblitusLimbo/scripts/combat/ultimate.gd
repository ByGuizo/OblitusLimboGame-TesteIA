class_name Ultimate
extends Node
## Ultimates cinematográficos (estilo jutsu final do Storm 4), despertar e corte de finalização.
##   Ultimate.start(P)        → golpe de abertura; se acertar, cena com cortes de câmera.
##   Ultimate.awaken(P)       → mini-cena de 1 s e ativa Apagão / Manifestação Harmônica.
##   Ultimate.finisher_cut(P) → corte curto de câmera lenta quando um finalizador acerta um chefe.

static var running: Ultimate = null
static var _last_cut := -99.0

var P: Player
var tgt = null
var frozen: Array = []
var _aura = null
var hidden: Array = []
var kind := "start"

# ---------------------------------------------------------------------
#  API
# ---------------------------------------------------------------------
static func start(p: Player) -> void:
	if running != null and is_instance_valid(running):
		return
	var u := Ultimate.new()
	u.P = p
	u.kind = "start"
	Game.main.add_child(u)
	running = u
	u._run_start()

static func awaken(p: Player) -> void:
	if running != null and is_instance_valid(running):
		return
	var u := Ultimate.new()
	u.P = p
	u.kind = "awaken"
	Game.main.add_child(u)
	running = u
	u._run_awaken()

static func finisher_cut(p: Player) -> void:
	if running != null and is_instance_valid(running):
		return
	if Game.cine or Game.real_time - _last_cut < 6.0:
		return
	var b = Game.boss
	if b == null or not is_instance_valid(b) or not b.alive:
		return
	if Game.dist2d(b.global_position, p.global_position) > 5.0:
		return
	_last_cut = Game.real_time
	Game.cam.shot(CamShots.low_angle(p, b, 1.0 if randf() < 0.5 else -1.0, 3.6, 50.0, 0.7))
	Game.slow(0.5, 0.3)
	Game.main.get_tree().create_timer(0.75, false, false, true).timeout.connect(func():
		if not Game.cine and Game.cam.mode == "cine":
			Game.cam.release(0.3))

# ---------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------
func _wait(t: float) -> void:
	await get_tree().create_timer(t, false, false, true).timeout

func _aborted() -> bool:
	return Game.cine or not is_instance_valid(P) or not P.alive

func _freeze(on: bool) -> void:
	Game.ult_freeze = on
	if on:
		for a in Game.actors:
			if is_instance_valid(a) and a != P and a != tgt and a.process_mode != Node.PROCESS_MODE_DISABLED:
				a.process_mode = Node.PROCESS_MODE_DISABLED
				frozen.append(a)
				# figurantes perto do alvo saem de cena para não taparem a câmera
				if tgt and is_instance_valid(tgt) and Game.dist2d(a.global_position, tgt.global_position) < 6.0 and a.visible:
					a.visible = false
					hidden.append(a)
		if tgt and is_instance_valid(tgt):
			tgt.scripted = true
			if tgt is Player:
				# oponente jogável (Versus): fica atordoado durante toda a cena
				tgt.cur_move = {}
				tgt.queue.clear()
				tgt._end_charge(false)
				tgt.set_state("hit")
				tgt.state_lock = 0.6
				tgt.rig.play("Hit_Chest", {"speed": 1.0, "blend": 0.05})
	else:
		for a in frozen:
			if is_instance_valid(a):
				a.process_mode = Node.PROCESS_MODE_INHERIT
		frozen.clear()
		for a in hidden:
			if is_instance_valid(a):
				a.visible = true
				Game.fx.burst("shadow", a.global_position + Vector3(0, 1, 0), {"n": 6, "r": 0.3})
		hidden.clear()
		if tgt and is_instance_valid(tgt):
			tgt.scripted = false

func _begin_cine() -> void:
	_freeze(true)
	P.invulnerable = true
	P.lock_target = null
	if Game.ui:
		Game.ui.cine(true)

func _end(release := true) -> void:
	_freeze(false)
	if Game.post: Game.post.speed_target = 0.0
	Game.fx.aura_end(_aura)
	_aura = null
	if is_instance_valid(P):
		P.invulnerable = false
		if P.state == "cast" or P.state == "ult":
			P.set_state("move")
		P.rig.stop_action(0.2)
	if Game.ui and not Game.cine:
		Game.ui.cine(false)
	if release and not Game.cine:
		Game.cam.release(0.45)
	running = null
	queue_free()

func _hit(dmg: float, o := {}) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.alive:
		return
	var oo := {"heavy": true, "knock": 0.0, "reaction": "stagger", "hitstop": 0.06, "shake": 0.25, "fury_gain": 0.0, "unblockable": true, "unavoidable": true}
	oo.merge(o, true)
	# no Versus o Ultimate tira ~25-30% da vida, como no Storm
	Game.damage(P, tgt, dmg * (1.7 if P.versus else 1.0), oo)

func _place_around(ang: float, dist: float) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	var y: float = tgt.yaw + ang
	var p: Vector3 = tgt.global_position + Vector3(sin(y), 0, cos(y)) * dist
	if Game.level and Game.level.has_method("clamp_point"):
		p = Game.level.clamp_point(p, 0.4)
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 14, "r": 0.4, "speed": 2.0})
	P.global_position = Vector3(p.x, P.global_position.y, p.z)
	P.snap_face(tgt.global_position)
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 14, "r": 0.4, "speed": 2.0})

# ---------------------------------------------------------------------
#  Golpe de abertura: se acertar, entra a cena
# ---------------------------------------------------------------------
func _run_start() -> void:
	tgt = P.auto_target(7.5)
	if tgt == null:
		tgt = Game.nearest_enemy(P, 7.5)
	var info: Dictionary = P.fk.ult_info()
	P.fury = 0.0
	P.set_state("ult")
	P.queue.clear()
	Audio.sfx("blink")
	Game.cam.kick(6.0)
	# investida
	if tgt:
		P.snap_face(tgt.global_position)
	P.rig.play(String(info.get("rush", "Sword_Dash")), {"speed": 1.8, "from": 0.18, "blend": 0.05})
	var t0 := 0.0
	var connected := false
	while t0 < 0.3:
		await get_tree().physics_frame
		t0 += get_physics_process_delta_time()
		if tgt and is_instance_valid(tgt) and tgt.alive:
			var d := Game.dist2d(P.global_position, tgt.global_position)
			if d > tgt.radius + 1.0:
				P.move_dir((tgt.global_position - P.global_position).normalized(), 22.0, get_physics_process_delta_time(), 60.0)
			else:
				connected = true
				break
		else:
			P.move_dir(P.forward(), 14.0, get_physics_process_delta_time(), 40.0)
	if not connected or _aborted():
		# errou: perde parte da fúria e volta ao combate
		P.fury = 60.0
		if Game.ui and P.brain == null: Game.ui.toast("ERROU!", Color(0.8, 0.8, 0.8), 0.8)
		P.move_vel = Vector3.ZERO
		_end(false)
		return
	P.move_vel = Vector3.ZERO
	Game.hitstop = 0.12
	Game.cam.shake(0.4)
	Audio.sfx("hitHeavy")
	_begin_cine()
	if Game.post: Game.post.speed_target = 0.6
	var ult_name: String = info.name
	var ult_col: Color = info.col
	if Game.ui:
		await Game.ui.cutin(P.kit, ult_name, ult_col)
	if Game.post: Game.post.speed_target = 0.0
	if _aborted():
		_end()
		return
	await P.fk.ult_sequence(self)
	_end()

# ---------------------------------------------------------------------
#  Kiana — Réquiem do Apagão
# ---------------------------------------------------------------------
func _seq_kiana() -> void:
	_aura = Game.fx.aura(P, Color(0.9, 0.02, 0.08), Color(0.1, 0.0, 0.03), 2.2)
	Game.flags["apagao"] = true
	P.rig.set_eye_glow(Color(3.0, 0.05, 0.02))
	P.rig.set_face(true)
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 1.25, 0.35, 32.0, 1.0), -0.18))
	Audio.sfx("fury")
	if Game.post: Game.post.flash = 0.35
	Game.fx.burst("shadow", P.global_position + Vector3(0, 1, 0), {"n": 40, "r": 0.6, "speed": 3.0, "size": 1.4})
	await _wait(0.75)
	if _aborted(): return
	var anims := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_A", "Sword_Regular_C", "Sword_Regular_B"]
	var angs := [PI * 0.5, -PI * 0.6, PI * 0.9, -PI * 0.2, PI * 0.3]
	for i in 5:
		if _aborted() or tgt == null or not is_instance_valid(tgt): return
		_place_around(angs[i], 1.3)
		Audio.sfx("blink", 0.7)
		P.rig.play(anims[i], {"speed": 2.2, "from": 0.25 if anims[i] == "Sword_Regular_C" else 0.0, "blend": 0.0})
		Game.cam.shot(CamShots.dutch(CamShots.around(tgt, angs[i] + PI * (0.75 if i % 2 == 0 else -0.75), 2.6, 1.0 + (i % 2) * 0.9, 44.0, 0.4), 0.25 if i % 2 == 0 else -0.25))
		if Game.post: Game.post.speed_target = 0.5
		await _wait(0.12)
		Game.fx.slash(P.global_position + Vector3(0, 1.1, 0), P.yaw, {"color": Color(1, 0.16, 0.16), "dark": true, "intensity": 3.0, "roll": randf_range(-1.5, 1.5), "big": true})
		Game.fx.afterimage(P, Color(1, 0.12, 0.2), 0.5)
		Game.fx.trail(P.rig, Color(1, 0.15, 0.2), 0.2)
		_hit(14.0, {"hitstop": 0.05})
		Game.fx.burst("blood", tgt.chest_pos(), {"n": 8})
		if Game.post: Game.post.impact = 0.4
		await _wait(0.2)
	if _aborted(): return
	# golpe final: salto e queda com câmera baixa
	_place_around(PI, 1.6)
	if Game.post: Game.post.speed_target = 0.0
	Game.cam.shot(CamShots.crash_zoom(P, tgt, 1.4))
	P.rig.play("NinjaJump_Land", {"speed": 1.1, "blend": 0.0})
	P.vy = 6.0
	await _wait(0.34)
	if _aborted(): return
	Audio.sfx("crit"); Audio.sfx("explosion", 0.8)
	Game.cam.shake(1.0)
	if Game.post:
		Game.post.impact_frames(0.09, Color(1.0, 0.85, 0.88))
		Game.post.flash = 0.5
		Game.post.impact = 1.0
	Game.fx.shockwave(tgt.global_position, Color(1, 0.06, 0.12), 7.0, {"glow": Color(1.0, 0.05, 0.12)})
	Game.fx.impact(tgt.chest_pos(), Color(1, 0.2, 0.25), 4.5)
	Game.fx.burst("shadow", tgt.chest_pos(), {"n": 50, "r": 0.8, "speed": 3.0, "size": 1.4})
	Game.fx.burst("spark", tgt.chest_pos(), {"n": 40, "color": Color(1, 0.4, 0.4)})
	_hit(110.0 * P.dmg_mul(), {"knock": 14.0, "reaction": "knockback", "hitstop": 0.2, "shake": 0.8, "crit": true})
	Game.slow(0.7, 0.25)
	await _wait(0.9)
	Game.flags["apagao"] = P.fury_active > 0.0
	if P.fury_active <= 0.0:
		P.rig.set_eye_glow(Color(1.4, 0.1, 0.05))
		P.rig.set_face(false)

# ---------------------------------------------------------------------
#  Kiana — Acorde Final (Manifestação Harmônica)
# ---------------------------------------------------------------------
func _seq_harmonic() -> void:
	_aura = Game.fx.aura(P, Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.45), 2.2)
	P.ukulele_front(true)
	P.rig.play("Spell_Simple_Idle", {"loop": true, "blend": 0.1})
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 1.4, -0.4, 34.0, 1.2), 0.15))
	Audio.sfx("reveal")
	if Game.post: Game.post.harmonic = 1.0
	await _wait(0.9)
	Game.cam.shot(CamShots.orbit(P.global_position, 5.0, 2.0, P.yaw + 0.6, P.yaw + 2.2, 2.4, 1.3, 48.0))
	for i in 6:
		if _aborted() or tgt == null or not is_instance_valid(tgt): break
		Audio.chord(i % 4)
		var start: Vector3 = P.global_position + Vector3(randf_range(-1, 1), 1.2 + randf(), randf_range(-1, 1))
		Game.spawn_projectile({"kind": "crescent", "pos": start, "vel": (tgt.chest_pos() - start).normalized() * 18.0, "team": P.team, "dmg": 0.0, "radius": 0.6, "life": 1.2, "src": P,
			"color": Color(0.38, 0.95, 1.0) if i % 2 else Color(1, 0.82, 0.44), "color2": Color(1, 1, 1), "target": tgt, "homing": 8.0, "scale": 1.3, "fury_gain": 0.0})
		_hit(12.0, {"hitstop": 0.03, "reaction": "flinch"})
		await _wait(0.3)
	if _aborted(): return
	Game.cam.shot(CamShots.low_angle(P, tgt, -1.0, 4.0, 56.0, 1.3))
	await _wait(0.2)
	Audio.sfx("shock"); Audio.sfx("gong", 0.6)
	Game.cam.shake(0.9)
	if Game.post:
		Game.post.impact_frames(0.08, Color(0.85, 0.97, 1.0))
		Game.post.flash = 0.5
		Game.post.impact = 0.9
	Game.fx.shockwave(P.global_position, Color(1, 0.82, 0.48), 9.0, {"glow": Color(1.0, 0.8, 0.4), "debris": false})
	Game.fx.impact(tgt.chest_pos(), Color(0.6, 0.95, 1.0), 4.0)
	Game.fx.burst("gold", tgt.chest_pos(), {"n": 60, "r": 1.5})
	_hit(120.0, {"knock": 12.0, "reaction": "knockback", "hitstop": 0.18, "shake": 0.7, "crit": true})
	if tgt and is_instance_valid(tgt):
		tgt.resonance = mini(99, tgt.resonance + 10)
	Game.slow(0.6, 0.3)
	await _wait(0.8)
	P.ukulele_front(false)
	if Game.post and P.ult == null: Game.post.harmonic = 0.0

# ---------------------------------------------------------------------
#  Viktor — Punho Flamejante
# ---------------------------------------------------------------------
func _seq_viktor() -> void:
	_aura = Game.fx.aura(P, Color(1.0, 0.45, 0.1), Color(1.0, 0.95, 0.7), 2.2)
	Game.cam.shot(CamShots.dutch(CamShots.closeup(P, 1.6, 0.6, 34.0, 1.2, -0.25), -0.2))
	Audio.sfx("fury")
	var fist := P.rig.attach_model(Game.fx.glow_ball(Color(4.0, 3.2, 1.8), 0.2), "hand_r", Transform3D(Basis(), P.rig.skel.get_bone_global_rest(P.rig.skel.find_bone("hand_r")).origin))
	for i in 10:
		Game.fx.burst("fire", P.rig.bone_world("hand_r"), {"n": 3, "r": 0.1, "size": 0.7})
		await _wait(0.07)
	if is_instance_valid(fist): fist.queue_free()
	if _aborted(): return
	Game.cam.shot(CamShots.crash_zoom(P, tgt, 1.6))
	await _wait(0.1)
	P.set_state("move")
	Game.main.get_tree().create_timer(0.3, false, false, true).timeout.connect(func():
		if Game.post: Game.post.impact_frames(0.09, Color(1.0, 0.92, 0.75)))
	P.punho_flamejante()        # golpe original: explosão + evento "punho" usado pelo roteiro
	await _wait(1.3)

# ---------------------------------------------------------------------
#  Despertar (segurar F)
# ---------------------------------------------------------------------
func _run_awaken() -> void:
	var harmonic: bool = Game.flags.get("harmonic", false)
	P.set_state("ult")
	P.queue.clear()
	_begin_cine()
	Game.cam.shot(CamShots.closeup(P, 1.5, 0.45, 36.0, 1.0))
	P.rig.play("Spell_Simple_Enter" if P.rig.has_anim("Spell_Simple_Enter") else "Idle_Shield_Break", {"speed": 1.2, "blend": 0.05})
	Game.fx.burst("shadow" if not harmonic else "magic", P.global_position + Vector3(0, 1, 0), {"n": 30, "r": 0.6, "speed": 2.0, "color": Color(0.38, 0.95, 1.0) if harmonic else Color(0.1, 0.0, 0.03)})
	Audio.sfx("heartbeat", 1.4)
	await _wait(0.8)
	_end()
	if not is_instance_valid(P) or Game.cine:
		return
	P.set_state("move")
	P.activate_fury()
