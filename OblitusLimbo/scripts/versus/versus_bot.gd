class_name VersusBot
extends RefCounted
## CPU do modo Versus: lê a luta como um jogador e "aperta botões" no Player (entradas virtuais).
## Usa exatamente o mesmo kit do jogador: combos, pesados, habilidades, investida, defesa,
## esquiva, Substituição, carga de chakra e Ultimate.

const DIFF := {
	"easy": {"think": 0.34, "react": 0.34, "guard": 0.2, "dodge": 0.08, "subs": 0.12, "combo": [2, 3], "aggr": 0.45, "skill": 0.22, "ult": 0.45, "finisher": 0.35},
	"normal": {"think": 0.2, "react": 0.2, "guard": 0.42, "dodge": 0.22, "subs": 0.4, "combo": [3, 4], "aggr": 0.62, "skill": 0.38, "ult": 0.8, "finisher": 0.6},
	"hard": {"think": 0.12, "react": 0.1, "guard": 0.58, "dodge": 0.36, "subs": 0.75, "combo": [4, 5], "aggr": 0.78, "skill": 0.5, "ult": 1.0, "finisher": 0.8},
}

var me                       # Player controlado
var p: Dictionary            # parâmetros da dificuldade
var move := Vector3.ZERO     # direção desejada (mundo)
var _just := {}              # ações apertadas neste quadro
var _held := {}              # ação → tempo restante segurando
var plan: Array = []         # [atraso, "press"/"hold", ação, duração]
var think_t := 0.5
var strafe := 1.0
var strafe_t := 0.0
var mode := "approach"
var mode_t := 0.0
var defend_t := 0.0
var side_dir := Vector3.ZERO

func _init(player, diff := "normal") -> void:
	me = player
	p = DIFF.get(diff, DIFF.normal)

# ---- interface usada pelo Player ----
func just(a: String) -> bool:
	return _just.has(a)

func held(a: String) -> bool:
	return _held.get(a, 0.0) > 0.0

func post_frame() -> void:
	_just.clear()

# ---- agenda de comandos ----
func press(a: String, delay := 0.0) -> void:
	plan.append([delay, "press", a, 0.0])

func hold(a: String, dur: float, delay := 0.0) -> void:
	plan.append([delay, "hold", a, dur])

func _planned(a: String) -> bool:
	for x in plan:
		if x[2] == a:
			return true
	return false

func clear() -> void:
	plan.clear()
	_held.clear()
	_just.clear()
	move = Vector3.ZERO

# ---------------------------------------------------------------------
func tick(dt: float) -> void:
	for k in _held.keys():
		_held[k] -= dt
		if _held[k] <= 0.0:
			_held.erase(k)
	for x in plan.duplicate():
		x[0] -= dt
		if x[0] <= 0.0:
			plan.erase(x)
			if x[1] == "press":
				_just[x[2]] = true
			else:
				_held[x[2]] = x[3]
	var o = me.opponent
	if o == null or not is_instance_valid(o) or not o.alive:
		move = Vector3.ZERO
		return
	var to: Vector3 = o.global_position - me.global_position
	to.y = 0
	var d := to.length()
	var dir: Vector3 = to / d if d > 0.01 else me.forward()
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.2, 2.8)
		strafe = -strafe
	var side := Vector3(-dir.z, 0, dir.x) * strafe
	mode_t -= dt
	_react(o, d, dt)
	think_t -= dt
	if think_t <= 0.0:
		think_t = p.think * randf_range(0.7, 1.3)
		_decide(o, d)
	match mode:
		"approach":
			move = (dir + side * 0.3).normalized()
		"strafe":
			var pref: float = maxf(4.0, float(me.K.get("ai_range", 2.0)))
			move = (side + dir * clampf((d - pref) * 0.5, -0.7, 0.7)).normalized()
		"retreat":
			move = (-dir * 0.8 + side * 0.6).normalized()
			if mode_t <= 0.0:
				mode = "strafe"
		"sidestep":
			move = side_dir
			if mode_t <= 0.0:
				mode = "strafe"
		"attack":
			var pref2: float = float(me.K.get("ai_range", 1.7))
			move = dir if d > pref2 else (-dir * 0.6 if d < pref2 - 2.0 else Vector3.ZERO)
		_:
			move = Vector3.ZERO
	if me.state == "attack":
		move = dir * 0.4 if d > 2.0 else Vector3.ZERO

# ---- reações (defesa, esquiva, Substituição) ----
func _react(o, d: float, dt: float) -> void:
	defend_t -= dt
	# Substituição quando está apanhando em combo
	if me.state == "hit" and me.subs >= 1.0 and me.combo_hits >= 2 and not _planned("dodge") and not me.scripted:
		if randf() < p.subs * dt * 5.0:
			press("dodge", p.react * 0.5)
	if defend_t > 0.0 or not (me.state == "idle" or me.state == "move"):
		return
	# golpe do oponente começando perto
	var threat: bool = (o.state == "attack" or o.state == "chase") and d < 3.4
	# projéteis vindo na minha direção
	if not threat:
		for pr in Game.projectiles:
			if pr.team == me.team:
				continue
			var rel: Vector3 = me.global_position - pr.pos
			rel.y = 0
			if rel.length() < 6.0 and pr.vel.normalized().dot(rel.normalized()) > 0.8:
				threat = true
				break
	if threat:
		defend_t = 0.55
		var r := randf()
		if r < p.guard:
			plan.clear()
			hold("guard", randf_range(0.35, 0.7), p.react)
		elif r < p.guard + p.dodge:
			plan.clear()
			var to: Vector3 = o.global_position - me.global_position
			to.y = 0
			var dir := to.normalized()
			side_dir = Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
			mode = "sidestep"
			mode_t = 0.3
			press("dodge", p.react + 0.03)

# ---- decisões táticas ----
## Escolhe uma habilidade que faça sentido para a distância (lê o "ai" de cada habilidade do kit).
func _pick_skill(d: float, e: float) -> int:
	var cands := []
	for i in me.skills.size():
		var sk: Dictionary = me.skills[i]
		if me.cd[i] > 0.0 or e < float(sk.cost):
			continue
		var ai: Dictionary = sk.get("ai", {})
		var rng: float = ai.get("range", 8.0)
		var ok := false
		match String(ai.get("kind", "ranged")):
			"ranged", "mobility": ok = d >= 3.5 and d <= rng
			"aoe": ok = d <= rng * 0.75
			"close", "grab": ok = d <= rng
			"trap": ok = d <= rng
			"buff": ok = true
		if ok:
			cands.append(i)
	return -1 if cands.is_empty() else cands[randi() % cands.size()]

func _use_skill(i: int) -> void:
	press("skill%d" % (i + 1))
	var kind: String = me.skills[i].get("ai", {}).get("kind", "")
	if kind == "mobility" or kind == "grab":
		_combo(0.5, 2)
	think_t = 0.6

func _decide(o, d: float) -> void:
	if not (me.state == "idle" or me.state == "move") or not plan.is_empty() or not _held.is_empty():
		return
	var e: float = me.energy
	var pref: float = float(me.K.get("ai_range", 2.0))    # distância preferida (zoners ficam longe)
	var zoner := pref > 4.0
	# oponente invisível / eu cego: recua e espera
	if o.untargetable or me.st_blind > 0.0:
		mode = "retreat"
		mode_t = 0.5
		return
	# Ultimate com fúria cheia
	if me.fury >= 100.0 and me.fury_active <= 0.0 and d < 6.0 and randf() < p.ult * 0.5:
		mode = "attack"
		var force: String = p.get("force", "")
		if force == "awaken" or (force == "" and me.fk.has_awaken() and (me.hp / me.max_hp < 0.55 or randf() < 0.3) and randf() < 0.5):
			hold("fury", 0.6)
		else:
			press("fury")
		think_t = 1.5
		return
	if d > 8.0:
		if e < 35.0 and randf() < 0.5:
			mode = "idle"
			hold("potion", randf_range(0.9, 1.6))
			think_t = 1.0
			return
		var si := _pick_skill(d, e)
		if si >= 0 and randf() < p.skill:
			_use_skill(si)
			return
		if not zoner and e >= 10.0 and randf() < 0.55:
			press("sprint")
			_combo(0.35)
			return
		if zoner and randf() < 0.6:
			mode = "attack"
			_combo(0.0, 3)
			return
		mode = "approach"
		return
	if d > 3.0:
		var r := randf()
		var si := _pick_skill(d, e)
		if si >= 0 and r < p.skill:
			_use_skill(si)
		elif zoner and r < p.skill + p.aggr * 0.6:
			mode = "attack"
			_combo(0.0, 4)
		elif not zoner and r < p.skill + p.aggr * 0.25 and e >= 10.0:
			press("sprint")
			_combo(0.3)
		elif r < p.skill + p.aggr:
			mode = "strafe" if zoner else "approach"
		else:
			mode = "strafe"
		return
	# curta distância
	var sc := _pick_skill(d, e)
	if sc >= 0 and randf() < p.skill * 0.45:
		_use_skill(sc)
		return
	if zoner and randf() < 0.55:
		# zoner perto demais: esquiva para trás e abre distância
		mode = "retreat"
		mode_t = randf_range(0.5, 0.9)
		if me.stamina > 30.0 and randf() < 0.5:
			press("dodge", 0.05)
		return
	if randf() < p.aggr:
		mode = "attack"
		_combo()
	else:
		var r := randf()
		if r < 0.4:
			mode = "retreat"
			mode_t = randf_range(0.4, 0.9)
		elif r < 0.65:
			hold("guard", randf_range(0.3, 0.6))
		else:
			mode = "strafe"

## Sequência de leves com chance de fechar com o pesado (ramo/finalizador do grafo de combos).
func _combo(delay := 0.0, nmax := -1) -> void:
	var n: int = randi_range(p.combo[0], p.combo[1])
	if nmax > 0:
		n = mini(n, nmax)
	var t := delay
	for i in n:
		press("attack", t)
		t += randf_range(0.17, 0.25)
	if randf() < p.finisher:
		press("heavy", t)
		t += 0.3
	think_t = t + randf_range(0.2, 0.45)
