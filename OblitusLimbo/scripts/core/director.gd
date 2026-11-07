extends Node
## Diretor de roteiro (porte do Director de main.js): esperas em tempo de jogo com token de
## abortar. Esperas descartadas no abort nunca retomam (a corrotina é abandonada).

class WaitHandle extends RefCounted:
	signal done
	var cond: Callable
	var t := 0.0
	var dur := -1.0
	var token := 0

var token := 0
var waits: Array[WaitHandle] = []
var listeners: Array = []
var cur := {"ch": 0, "seg": 0}
var story: Node
var running := false
var skipping := false            # avanço rápido da cutscene atual (segurar Enter/Espaço)
var _prompted := false

func _process(delta: float) -> void:
	var ws := waits.duplicate()
	for w in ws:
		if w.token != token:
			waits.erase(w)
			continue
		w.t += delta
		var ok := false
		if w.dur >= 0.0:
			ok = w.t >= w.dur or skipping
		elif w.cond.is_valid():
			ok = w.cond.call()
		else:
			ok = true
		if ok:
			waits.erase(w)
			w.done.emit()

func until(cond: Callable) -> Signal:
	var h := WaitHandle.new()
	h.cond = cond
	h.token = token
	waits.append(h)
	return h.done

func wait(sec: float) -> Signal:
	var h := WaitHandle.new()
	h.dur = sec
	h.token = token
	waits.append(h)
	return h.done

## Sinal que nunca dispara: usado para abandonar corrotinas de um trecho abortado.
func never() -> Signal:
	var h := WaitHandle.new()
	_dead.append(h)
	return h.done
var _dead: Array = []

## Pede para pular a cutscene atual (só quando há cena/cartão e nenhum QTE na tela).
func request_skip() -> void:
	if skipping:
		return
	if Game.ui and Game.ui.prompt_box.visible:
		return
	if not (Game.cine or (Game.ui and Game.ui.card_p != null)):
		return
	skipping = true
	Audio.sfx("whoosh", 0.5)

func _stop_skip() -> void:
	skipping = false

func abort() -> void:
	skipping = false
	token += 1
	waits.clear()
	_dead.clear()
	for l in listeners:
		if Game.ev.is_connected(l):
			Game.ev.disconnect(l)
	listeners.clear()
	if Game.ui:
		Game.ui.force_close()
		Game.ui.prompt("")
	Game.cine = false
	if Game.ui: Game.ui.cine(false)
	Game.flags = {}
	Audio.set_layer("harmonic", false)
	Audio.set_layer("viktor", false)
	if Game.post:
		Game.post.reset()
	_prompted = false

## Fim normal de um trecho: encerra tarefas paralelas e ouvintes que sobraram.
func end_segment() -> void:
	skipping = false
	token += 1
	waits.clear()
	_dead.clear()
	for l in listeners:
		if Game.ev.is_connected(l):
			Game.ev.disconnect(l)
	listeners.clear()
	if Game.ui:
		Game.ui.prompt("")
	_prompted = false

## Conecta a um evento do jogo enquanto o trecho estiver ativo.
func listen(ev_name: String, fn: Callable) -> void:
	var tok := token
	var c := func(n, data):
		if n == ev_name and tok == token:
			fn.call(data)
	Game.ev.connect(c)
	listeners.append(c)

# ---------------------------------------------------------------------
#  Utilidades de roteiro (com guarda de abort)
# ---------------------------------------------------------------------
func _guard(tok: int) -> bool:
	return tok == token

func load_level(name: String, o := {}) -> void:
	var tok := token
	await Game.main.load_level(name, o)
	if not _guard(tok): await never()

func say(lines: Array, keep_cine := false) -> void:
	var tok := token
	cine(true)
	await Game.ui.dialogue(lines)
	if not _guard(tok): await never()
	if not keep_cine:
		cine(false)

func card(o: Dictionary) -> void:
	var tok := token
	await Game.ui.card(o)
	if not _guard(tok): await never()

func fade(v: float, d := 1.0) -> void:
	var tok := token
	await Game.ui.fade(v, d)
	if not _guard(tok): await never()

func cine(on: bool) -> void:
	if on and Ultimate.running != null and is_instance_valid(Ultimate.running):
		Ultimate.running._end(false)
	Game.cine = on
	if Game.ui: Game.ui.cine(on)
	if not on:
		skipping = false
	var P = Game.player
	if P and is_instance_valid(P):
		if on:
			P.set_state("cine")
			P.rig.stop_action(0.2)
			P.lock_target = null
			if P.fury_active > 0.0:
				P.end_fury()
		elif P.state == "cine":
			P.set_state("move")
	if not on and Game.cam:
		Game.cam.release(0.9)

func shot(o: Dictionary) -> void:
	if skipping:
		o = o.duplicate()
		o["cut"] = true
	Game.cam.shot(o)

func objective(title, text: String, pos = null) -> void:
	Game.ui.quest(title, text)
	Game.objective = pos

func reach(pos: Vector3, r := 2.0) -> Signal:
	return until(func(): return Game.player and is_instance_valid(Game.player) and Game.dist2d(Game.player.global_position, pos) < r)

func interact(target, r: float, label: String) -> Signal:
	return until(func():
		var P = Game.player
		if P == null or Game.cine:
			return false
		if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
			return false
		var pos: Vector3 = target.global_position if target is Node3D else target
		var near := Game.dist2d(P.global_position, pos) < r
		if near:
			Game.ui.prompt("[E]  " + label)
			_prompted = true
		elif _prompted:
			Game.ui.prompt("")
			_prompted = false
		if near and Input.is_action_just_pressed("interact"):
			Game.ui.prompt("")
			_prompted = false
			return true
		return false)

## Executa uma corrotina em paralelo (sem esperar por ela).
func task(fn: Callable) -> void:
	fn.call()
