class_name Versus
extends Node
## Modo Versus local (1 x CPU) estilo Naruto Storm: apresentação, rounds com cronômetro,
## K.O. em câmera lenta, pose de vitória e tela de resultado.

const ARENAS := {
	"throne": {"name": "Salão do Trono", "music": "boss_krauser", "c": Vector3.ZERO},
	"tavern": {"name": "Taverna de Darius", "music": "boss_darius", "c": Vector3(0, 0, 0.5)},
	"valley": {"name": "Vale das Flores Sangrentas", "music": "battle", "c": Vector3.ZERO},
	"domain": {"name": "A Barreira", "music": "boss_elemental", "c": Vector3.ZERO},
	"limbo": {"name": "O Limbo", "music": "limbo", "c": Vector3.ZERO},
}
## Dados do lutador vindos do kit (nome, título, vida no Versus…).
static func fighter(id: String) -> Dictionary:
	return Kits.info(id)
const ROUND_TIME := 99.0

var cfg := {"p1": "kiana", "cpu": "viktor", "arena": "throne", "diff": "normal", "rounds": 2}
var p1: Player
var cpu: Player
var wins := [0, 0]
var round_n := 0
var timer := ROUND_TIME
var fighting := false
var aborted := false
var saved_flags := {}

static func start(c: Dictionary) -> Versus:
	if Game.versus and is_instance_valid(Game.versus):
		Game.versus.abort()
	var v := Versus.new()
	v.name = "Versus"
	v.cfg = c.duplicate()
	v.process_mode = Node.PROCESS_MODE_PAUSABLE
	Game.main.add_child(v)
	Game.versus = v
	v._run()
	return v

func abort() -> void:
	if aborted:
		return
	aborted = true
	fighting = false
	if Game.versus == self:
		Game.versus = null
	Game.flags = saved_flags
	# libera depois: corrotinas pendentes acordam, veem `aborted` e saem
	get_tree().create_timer(5.0, true, false, true).timeout.connect(queue_free)

func _gone() -> bool:
	return aborted or not is_inside_tree()

func _wait(t: float) -> void:
	await get_tree().create_timer(t, false, false, true).timeout

func _arena_center() -> Vector3:
	return ARENAS.get(cfg.arena, ARENAS.throne).c

# ---------------------------------------------------------------------
func _run() -> void:
	var M = Game.main
	M.run_token += 1
	D.abort()
	M.mode = "versus"
	M.dead = false
	M.get_tree().paused = false
	M.menus.hide_all()
	saved_flags = Game.flags.duplicate()
	Game.flags = {}
	var ar: Dictionary = ARENAS.get(cfg.arena, ARENAS.throne)
	LevelBase.arena = true
	await M.load_level(cfg.arena, {"label": String(ar.name).to_upper()})
	LevelBase.arena = false
	if _gone():
		return
	Audio.stop_loops()
	Audio.music(ar.music, 1.0)
	var c := _arena_center()
	p1 = Player.new()
	p1.setup_player(cfg.p1, {"pos": c + Vector3(0, 0, -4), "yaw": 0.0})
	Game.world.add_child(p1)
	cpu = Player.new()
	cpu.setup_player(cfg.cpu, {"pos": c + Vector3(0, 0, 4), "yaw": PI})
	cpu.team = "enemy"
	cpu.brain = VersusBot.new(cpu, cfg.diff)
	Game.world.add_child(cpu)
	if cfg.p1 == cfg.cpu:
		# espelho: o CPU ganha um tom violeta para diferenciar
		cpu.rig.set_tint(0.78, Color(0.85, 0.72, 1.0))
	var hpk := 0.15 if M.args.has("vsquick") else 1.0     # teste: rounds curtos
	p1.setup_versus(cpu, fighter(cfg.p1).vs_hp * hpk)
	cpu.setup_versus(p1, fighter(cfg.cpu).vs_hp * hpk)
	cpu.display_name = "CPU · " + String(fighter(cfg.cpu).name)
	if String(M.args.get("auto", "")) == "versus":
		p1.brain = VersusBot.new(p1, "normal")
	Game.player = p1
	Game.in_combat = true
	Game.ui.set_player(p1)
	Game.ui.boss(null)
	Game.ui.quest(null, "")
	Game.ui.show_hud(true)
	M._update_mouse()
	while not _gone():
		round_n += 1
		await _round()
		if _gone():
			return
		if wins[0] >= cfg.rounds or wins[1] >= cfg.rounds:
			break
	if not _gone():
		await _finish()

func _round() -> void:
	Game.clear_systems()
	Game.fx.clear()
	Game.flags["apagao"] = false
	if Game.post:
		Game.post.reset()
	var c := _arena_center()
	p1.versus_reset(c + Vector3(0, 0, -4.0), 0.0)
	cpu.versus_reset(c + Vector3(0, 0, 4.0), PI)
	if cpu.brain:
		cpu.brain.clear()
	if p1.brain:
		p1.brain.clear()
	p1.controllable = false
	cpu.controllable = false
	timer = ROUND_TIME
	fighting = false
	Game.cam.snap_to_player()
	if Game.main.args.has("showult"):
		# teste: P1 começa com a fúria cheia e o CPU fica mais passivo
		p1.fury = 100.0
		cpu.fury = 100.0 if String(Game.main.args.showult) == "both" else 0.0
		if cpu.brain: cpu.brain.p = cpu.brain.p.duplicate(); cpu.brain.p["aggr"] = 0.15; cpu.brain.p["ult"] = 4.0 if cpu.fury >= 100.0 else 0.0; cpu.brain.p["force"] = "ult"
		if p1.brain: p1.brain.p = p1.brain.p.duplicate(); p1.brain.p["ult"] = 4.0; p1.brain.p["force"] = "awaken" if String(Game.main.args.showult) == "awaken" else "ult"
	# apresentação
	if round_n == 1 and not Game.main.args.has("nointro"):
		Game.ui.cine(true)
		Game.cam.shot(CamShots.closeup(cpu, 1.5, -0.35, 38.0, 1.6))
		Game.ui.versus_banner(String(fighter(cfg.cpu).name).to_upper(), fighter(cfg.cpu).title, 1.5, Color(1, 0.35, 0.45), 0.76)
		await _wait(1.6)
		if _gone(): return
		Game.cam.shot(CamShots.closeup(p1, 1.5, 0.35, 38.0, 1.6))
		Game.ui.versus_banner(String(fighter(cfg.p1).name).to_upper(), fighter(cfg.p1).title, 1.5, Color(0.72, 0.6, 1.0), 0.76)
		await _wait(1.6)
		if _gone(): return
		Game.cam.shot(CamShots.orbit(c, 7.0, 2.2, PI * 1.25, PI * 1.55, 1.6, 1.2, 52.0))
		Game.ui.cine(false)
	else:
		Game.cam.shot(CamShots.orbit(c, 7.5, 2.0, PI * 1.15, PI * 1.45, 1.4, 1.2, 54.0))
	Audio.sfx("gong", 0.6)
	await Game.ui.versus_banner("ROUND %d" % round_n, "" if round_n < 3 else "ROUND FINAL", 1.2)
	if _gone(): return
	Game.cam.release(0.35)
	Audio.sfx("hitHeavy", 0.8)
	Game.ui.versus_banner("LUTEM!", "", 0.75, Color(1, 0.4, 0.3))
	await _wait(0.35)
	if _gone(): return
	p1.controllable = true
	cpu.controllable = true
	fighting = true
	# luta
	while not _gone():
		await get_tree().physics_frame
		if _gone(): return
		if Ultimate.running == null and not get_tree().paused:
			timer = maxf(0.0, timer - get_physics_process_delta_time())
		if not p1.alive or not cpu.alive or timer <= 0.0:
			break
	fighting = false
	while Ultimate.running != null and is_instance_valid(Ultimate.running):
		await get_tree().process_frame
		if _gone(): return
	var ko := not p1.alive or not cpu.alive
	var winner := -1
	if not cpu.alive and p1.alive:
		winner = 0
	elif not p1.alive and cpu.alive:
		winner = 1
	elif p1.alive and cpu.alive:
		var a: float = p1.hp / p1.max_hp
		var b: float = cpu.hp / cpu.max_hp
		winner = 0 if a > b + 0.001 else (1 if b > a + 0.001 else -1)
	p1.controllable = false
	cpu.controllable = false
	if cpu.brain: cpu.brain.clear()
	if p1.brain: p1.brain.clear()
	if winner >= 0:
		wins[winner] += 1
	if ko:
		Game.slow(1.8, 0.22)
		if Game.post:
			Game.post.impact_frames(0.1, Color(1.0, 0.9, 0.95))
		Audio.sfx("crit")
		Audio.sfx("gong", 0.7)
		var loser: Player = p1 if winner == 1 else cpu
		Game.cam.shot(CamShots.low_angle(p1 if winner != 1 else cpu, loser, 1.0, 4.0, 50.0, 1.8))
		await Game.ui.versus_banner("K.O.!", "", 1.6, Color(1, 0.25, 0.3))
	else:
		Audio.sfx("bell", 0.8)
		await Game.ui.versus_banner("TEMPO!", "", 1.3, Color(1, 0.85, 0.5))
	if _gone(): return
	# pose do vencedor do round
	if winner >= 0:
		var w: Player = p1 if winner == 0 else cpu
		w.rig.stop_action(0.2)
		Game.cam.shot(CamShots.closeup(w, 1.8, 0.4, 40.0, 1.8))
		var nm: String = fighter(cfg.p1 if winner == 0 else cfg.cpu).name
		await Game.ui.versus_banner(nm.to_upper(), "VENCE O ROUND" if winner == 0 else "CPU VENCE O ROUND", 1.5, Color(0.72, 0.6, 1.0) if winner == 0 else Color(1, 0.35, 0.45), 0.76)
	else:
		await Game.ui.versus_banner("EMPATE", "", 1.3)
	Game.cam.release(0.2)

func _finish() -> void:
	var won: bool = wins[0] > wins[1]
	var w: Player = p1 if won else cpu
	Game.ui.cine(true)
	w.rig.play(w.fk.win_anim(), {"loop": true, "blend": 0.3})
	Game.cam.shot(CamShots.closeup(w, 2.2, 0.55, 42.0, 3.0, -0.35))
	Audio.music("title", 2.0)
	await Game.ui.versus_banner("VITÓRIA" if won else "DERROTA", "%d  —  %d" % [wins[0], wins[1]], 2.4, Color(0.72, 0.6, 1.0) if won else Color(1, 0.3, 0.35))
	if _gone(): return
	Game.ui.cine(false)
	Game.main.mode = "versus_end"
	Game.ui.show_hud(false)
	Game.main.menus.show_versus_result(won, wins, cfg)
	Game.main._update_mouse()
