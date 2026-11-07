extends Node
## Harness de teste automático (ativado por -- --test=ch,seg --auto[=die|play]).
## Avança diálogos/cartões, leva o jogador aos objetivos, interage, luta (dano automático)
## e registra trechos, FPS e travamentos. Termina nos créditos.

var mode := "auto"
var t := 0.0
var seg_t := 0.0
var hit_t := 0.0
var fps_t := 0.0
var last_seg := ""
var press_t := 0
var died := false
var frames := 0
var fps_samples: Array = []
var max_seg_time := 300.0
var stop_after := ""
# modo "combo": sequências de entrada roteirizadas
var seqs := [
	["light", 0.12, "light", 0.12, "light", 0.12, "light", 1.6],
	["light", 0.12, "heavy", 1.2],
	["light", 0.12, "light", 0.12, "heavy", 1.3],
	["light", 0.12, "light", 0.12, "light", 0.12, "heavy", 1.6],
	["heavy", 1.4],
	["light", 0.06, "dodge", 0.25, "light", 1.0],
	["light", 0.05, "guard_on", 0.4, "guard_off", 0.6],
	["sprint_on", 0.45, "light", 0.2, "sprint_off", 1.0],
	["fury_full", 0.05, "fury_tap", 6.0],
]
var seq_i := 0
var step_i := 0
var step_t := 0.0
var last_move := ""
var last_state := ""
var skip_frames := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a: Dictionary = Game.main.args
	mode = String(a.get("auto", "1"))
	stop_after = String(a.get("stop", ""))
	Game.ev.connect(func(n, data):
		if n == "segment":
			var s := "%d,%d" % [data.ch, data.seg]
			_log("SEGMENT %s (t=%.1f)" % [s, t])
			if stop_after != "" and last_seg == stop_after:
				_log("STOP after %s" % stop_after)
				get_tree().quit()
			last_seg = s
			seg_t = 0.0
		elif n == "playerDead":
			_log("PLAYER DEAD at %s" % last_seg)
			died = true)

func _log(s: String) -> void:
	print("[HARNESS] ", s)

func _process(delta: float) -> void:
	var rdt: float = Game.real_dt()
	t += rdt
	seg_t += rdt
	frames += 1
	fps_t += rdt
	if fps_t > 5.0:
		fps_t = 0.0
		var f := Engine.get_frames_per_second()
		fps_samples.append(f)
		_log("t=%.0f seg=%s fps=%d draws=%d objs=%d vram=%.0fMB actors=%d" % [t, last_seg, f,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, Game.actors.size()])
	if mode == "versus":
		_versus_mode(rdt)
		return
	if seg_t > max_seg_time:
		_log("STUCK in %s (cine=%s objective=%s)" % [last_seg, Game.cine, Game.objective])
		get_tree().quit(2)
		return
	if Game.main.mode == "credits" or (Game.main.mode == "title" and t > 5.0):
		_log("REACHED %s — fim. fps médio=%.1f" % [Game.main.mode, _avg()])
		get_tree().quit()
		return
	if mode == "play":
		return
	var ui: UIRoot = Game.ui
	if mode == "skip":
		_skip_mode(ui)
		return
	# diálogos e cartões
	if ui.dlg != null:
		var d = ui.dlg
		if d.shown >= d.plain or randf() < 0.3:
			ui._next_line()
	if ui.card_p != null and not ui.card_p.closing and ui.card_p.t > 0.4:
		ui.card_p.t = 999.0
	# morte
	if died and Game.main.dead:
		died = false
		_log("retry")
		Game.main.restart_segment()
		return
	# interações / QTE
	if press_t > 0:
		press_t -= 1
		if press_t == 0:
			_act("interact", false)
	elif ui.prompt_box.visible:
		_act("interact", true)
		press_t = 3
	var P = Game.player
	if P == null or not is_instance_valid(P) or not P.alive or Game.cine:
		return
	if mode != "die":
		P.invulnerable = true
	# objetivos: teleporta para perto
	if Game.objective != null and not Game.in_combat:
		var o: Vector3 = Game.objective
		if Game.dist2d(P.global_position, o) > 1.6:
			var dir: Vector3 = (P.global_position - o)
			dir.y = 0
			dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
			P.global_position = o + dir * 1.4
	if Game.main.args.has("hudboss") and Game.in_combat and Game.ui.boss_actor == null:
		# depuração do HUD: mostra o inimigo mais próximo como chefe
		var nb = Game.nearest_enemy(P, 40.0)
		if nb:
			Game.ui.boss(nb)
	if mode == "combo":
		_combo_mode(P, rdt)
		return
	# modo "watch": luta com entradas simuladas (para gravar vídeo)
	hit_t -= rdt
	if mode == "watch":
		if Game.in_combat and hit_t <= 0.0:
			hit_t = 0.45
			var tgt = Game.nearest_enemy(P, 30.0)
			if tgt:
				P.snap_face(tgt.global_position)
				var d: float = Game.dist2d(P.global_position, tgt.global_position)
				if d > 2.2:
					P.global_position = P.global_position.lerp(tgt.global_position, 0.25)
				var r := randf()
				_act("attack", true)
				Game.after(0.05, func(): _act("attack", false))
				if r < 0.12:
					_act("skill1", true)
					Game.after(0.05, func(): _act("skill1", false))
				elif r < 0.18:
					_act("skill2", true)
					Game.after(0.05, func(): _act("skill2", false))
				if P.fury >= 100.0 and randf() < 0.3:
					_act("fury", true)
					Game.after(0.05, func(): _act("fury", false))
				if randf() < 0.3:
					Game.damage(P, tgt, 18.0 if not tgt.boss else tgt.max_hp * 0.012, {})
		return
	# combate: dano automático
	if Game.in_combat and hit_t <= 0.0:
		hit_t = 0.25
		var foes := Game.enemies_of(P)
		for e in foes:
			if e.invulnerable:
				continue
			Game.damage(P, e, 60.0 if not e.boss else e.max_hp * 0.03, {})
			break
		if P.kit == "viktor" and Game.boss and is_instance_valid(Game.boss) and Game.boss.hp <= Game.boss.max_hp * 0.32:
			Game.emit_ev("punho", Game.boss)

func _combo_mode(P, rdt: float) -> void:
	# registra transições de estado/golpe
	var mv: String = P.cur_move_id if P.state == "attack" else ""
	if mv != last_move or P.state != last_state:
		_log("COMBO t=%.2f state=%s move=%s pos=%.2f" % [t, P.state, mv, P.rig.action_pos()])
		last_move = mv
		last_state = P.state
	if not Game.in_combat or seq_i >= seqs.size():
		if seq_i >= seqs.size() and Game.in_combat:
			_log("COMBO done")
			get_tree().quit()
		return
	var tgt = Game.nearest_enemy(P, 40.0)
	if tgt == null:
		return
	tgt.invulnerable = false
	if tgt.hp < 30.0 and not tgt.boss:
		tgt.hp = tgt.max_hp
	step_t -= rdt
	if step_t > 0.0:
		return
	var sq: Array = seqs[seq_i]
	if step_i == 0:
		_log("SEQ %d %s" % [seq_i, str(sq)])
		var d: float = Game.dist2d(P.global_position, tgt.global_position)
		if d > 3.0:
			P.global_position = tgt.global_position - Game.fwd(Game.yaw_to(tgt.global_position, P.global_position) + PI) * 2.2
		P.snap_face(tgt.global_position)
	if step_i >= sq.size():
		seq_i += 1
		step_i = 0
		step_t = 0.6
		return
	var cmd: String = sq[step_i]
	var wait: float = sq[step_i + 1]
	step_i += 2
	step_t = wait
	match cmd:
		"light": _tap("attack")
		"heavy": _tap("heavy")
		"dodge": _tap("dodge")
		"guard_on": _act("guard", true)
		"guard_off": _act("guard", false)
		"sprint_on":
			_act("sprint", true); _act("move_f", true)
		"sprint_off":
			_act("sprint", false); _act("move_f", false)
		"fury_full": P.fury = 100.0
		"fury_tap": _tap("fury")

func _tap(a: String) -> void:
	_act(a, true)
	Game.after(0.04, func(): _act(a, false))

## Modo "skip": segura Enter/Espaço em toda cena; diálogos/cartões nunca são avançados à mão.
func _skip_mode(ui: UIRoot) -> void:
	var want: bool = (Game.cine or ui.card_p != null) and not ui.prompt_box.visible
	if want != (skip_frames > 0):
		_act("advance", want)
		skip_frames = 1 if want else 0
	if press_t > 0:
		press_t -= 1
		if press_t == 0:
			_act("interact", false)
	elif ui.prompt_box.visible:
		_act("interact", true)
		press_t = 3
	var P = Game.player
	if P == null or not is_instance_valid(P) or not P.alive or Game.cine:
		return
	P.invulnerable = true
	if Game.objective != null and not Game.in_combat:
		var o: Vector3 = Game.objective
		if Game.dist2d(P.global_position, o) > 1.6:
			P.global_position = o + Vector3(0, 0, -1.4)
	hit_t -= Game.real_dt()
	if Game.in_combat and hit_t <= 0.0:
		hit_t = 0.25
		for e in Game.enemies_of(P):
			if e.invulnerable:
				continue
			Game.damage(P, e, 60.0 if not e.boss else e.max_hp * 0.03, {})
			break
		if P.kit == "viktor" and Game.boss and is_instance_valid(Game.boss) and Game.boss.hp <= Game.boss.max_hp * 0.32:
			Game.emit_ev("punho", Game.boss)

func _act(a: String, on: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = on
	Input.parse_input_event(ev)

func _avg() -> float:
	if fps_samples.is_empty():
		return 0.0
	var s := 0.0
	for f in fps_samples:
		s += f
	return s / fps_samples.size()

# modo "versus": CPU x CPU, registra a partida e encerra no resultado
var vs_log_t := 0.0
var vs_end_t := 0.0
func _versus_mode(rdt: float) -> void:
	var V = Game.versus
	if Game.main.mode == "versus_end":
		vs_end_t += rdt
		if vs_end_t < 3.0:
			return
		_log("VERSUS FIM placar=%s fps médio=%.1f" % [str(V.wins) if V else "?", _avg()])
		get_tree().quit()
		return
	if V == null or not is_instance_valid(V) or V.p1 == null or V.cpu == null:
		return
	if t > 600.0:
		_log("VERSUS STUCK")
		get_tree().quit(2)
		return
	var ev := "%d|%s|%s" % [V.round_n, V.p1.state, V.cpu.state]
	vs_log_t -= rdt
	if vs_log_t <= 0.0:
		vs_log_t = 2.0
		_log("VS r=%d t=%.0f P1 %s hp=%.0f en=%.0f fu=%.0f sub=%.1f | CPU %s hp=%.0f en=%.0f fu=%.0f sub=%.1f ult=%s wins=%s" % [V.round_n, V.timer,
			V.p1.state, V.p1.hp, V.p1.energy, V.p1.fury, V.p1.subs, V.cpu.state, V.cpu.hp, V.cpu.energy, V.cpu.fury, V.cpu.subs,
			str(Ultimate.running != null), str(V.wins)])
