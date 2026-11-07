extends Node
## Estado global + sistemas de combate compartilhados (porte de world.js).

signal ev(name: String, data)

var main: Node                 # cena principal
var world: Node3D              # contêiner do nível atual
var level: Node3D              # LevelBase
var player: Node3D             # Player
var actors: Array = []
var boss: Node3D
var cam: Node3D                # CameraRig
var ui: Node                   # UIRoot
var fx: Node3D                 # FX
var post: Node                 # PostFX

var flags := {}
var time := 0.0
var real_time := 0.0
var hitstop := 0.0
var slow_t := 0.0
var slow_scale := 1.0
var cine := false
var in_combat := false
var attack_tokens := 0
var max_tokens := 2
var difficulty := 1.0
var wind := Vector3.ZERO
var objective = null
var kill_count := 0
var loading := false
const VERSUS_DMG := 0.34      # escala de dano entre lutadores no Versus (rounds de ~40 s)
var ult_freeze := false      # Ultimate em cena: projéteis, áreas e timers ficam parados
var versus = null            # partida do modo Versus em andamento (Versus) ou null

var timers: Array = []
var areas: Array = []
var projectiles: Array = []
var hazards: Array = []
var _last_us := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_last_us = Time.get_ticks_usec()

func _setup_input() -> void:
	var map := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN], "move_l": [KEY_A, KEY_LEFT], "move_r": [KEY_D, KEY_RIGHT],
		"dodge": [KEY_SPACE], "sprint": [KEY_SHIFT], "lock": [KEY_Q], "skill1": [KEY_1], "skill2": [KEY_2], "skill3": [KEY_3],
		"fury": [KEY_F], "guard": [KEY_C], "potion": [KEY_R, KEY_TAB], "interact": [KEY_E], "pause": [KEY_ESCAPE], "advance": [KEY_SPACE, KEY_ENTER, KEY_E],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["heavy", MOUSE_BUTTON_RIGHT], ["lock", MOUSE_BUTTON_MIDDLE], ["advance", MOUSE_BUTTON_LEFT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var m := InputEventMouseButton.new()
		m.button_index = pair[1]
		InputMap.action_add_event(pair[0], m)

# ---------------------------------------------------------------------
#  Tempo
# ---------------------------------------------------------------------
func real_dt() -> float:
	return _real_dt

var _real_dt := 0.016

func _process(delta: float) -> void:
	# tempo real = delta sem a escala de tempo (funciona também com --fixed-fps / movie maker)
	_real_dt = clampf(delta / maxf(Engine.time_scale, 0.0001), 0.0, 0.1)
	if get_tree().paused:
		return
	real_time += _real_dt
	if hitstop > 0.0:
		hitstop -= _real_dt
	if slow_t > 0.0:
		slow_t -= _real_dt
	var sc := 1.0
	if slow_t > 0.0:
		sc *= slow_scale
	if hitstop > 0.0:
		sc *= 0.05
	if D.skipping:
		sc = 8.0
	Engine.time_scale = sc
	time += delta
	if ult_freeze:
		return
	_update_timers(delta)
	_update_areas(delta)
	_update_projectiles(delta)
	_update_hazards(delta)

func slow(t: float, scale: float) -> void:
	slow_t = t
	slow_scale = scale

func after(sec: float, fn: Callable) -> void:
	timers.append([sec, fn])

func _update_timers(dt: float) -> void:
	var ts := timers
	timers = []
	for x in ts:
		x[0] -= dt
		if x[0] <= 0.0:
			if x[1].is_valid():
				x[1].call()
		else:
			timers.append(x)

func emit_ev(n: String, data = null) -> void:
	ev.emit(n, data)

# ---------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------
static func fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))

static func yaw_to(a: Vector3, b: Vector3) -> float:
	return atan2(b.x - a.x, b.z - a.z)

static func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

static func dist2d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func enemies_of(a) -> Array:
	var out := []
	for e in actors:
		if is_instance_valid(e) and e.alive and e.team != a.team and e.team != "neutral" and not e.untargetable:
			out.append(e)
	return out

func nearest_enemy(a, max_d := 99.0):
	var best = null
	var bd := max_d
	for e in enemies_of(a):
		var d := dist2d(a.global_position, e.global_position)
		if d < bd:
			bd = d; best = e
	return best

func allies_of_player() -> Array:
	var out := []
	for a in actors:
		if is_instance_valid(a) and a.alive and a.team == "player":
			out.append(a)
	return out

# ---------------------------------------------------------------------
#  Dano
# ---------------------------------------------------------------------
func damage(src, target, amount: float, o := {}) -> bool:
	if target == null or not is_instance_valid(target) or not target.alive or target.invulnerable:
		return false
	var P = player
	# postura de contra-ataque e afins (kit do alvo)
	if target is Player and target.fk and target.fk.intercept_hit(src, amount, o):
		return false
	var from: Vector3 = o.get("from", src.global_position if src and is_instance_valid(src) else target.global_position)
	# esquiva (i-frames) — esquiva perfeita
	if target.iframes > 0.0 and not o.get("unavoidable", false):
		if target is Player and target.dodge_t < 0.22 and not target.perfect_used:
			target.perfect_used = true
			target.gain_fury(15)
			target.fk.on_perfect_dodge(src)
			if target == P:
				slow(0.9, 0.25)
				if ui: ui.toast("ESQUIVA PERFEITA", Color(0.62, 0.85, 1.0))
				Audio.sfx("parry", 0.5)
				if post: post.flash = 0.25
		return false
	var dir: Vector3 = target.global_position - from
	dir.y = 0
	if dir.length_squared() < 0.0001:
		dir = fwd(src.yaw if src and is_instance_valid(src) else 0.0)
	dir = dir.normalized()
	# defesa / aparar
	if target.guarding and not o.get("unblockable", false):
		var facing: bool = abs(ang_diff(yaw_to(target.global_position, from), target.yaw)) < 1.2
		if facing:
			var pw: float = target.fk.parry_window() if target is Player and target.fk else 0.22
			if target.guard_t < pw and src and is_instance_valid(src) and src.has_method("stun"):
				src.stun(1.6)
				Audio.sfx("parry")
				fx.burst("spark", target.global_position + Vector3(0, 1.3, 0) - dir * 0.5, {"n": 30, "color": Color(1, 1, 1), "color2": Color(0.5, 0.75, 1.0)})
				fx.flash(target.global_position + Vector3(0, 1.4, 0), Color(0.75, 0.88, 1.0), 10.0, 0.2)
				slow(0.6, 0.3)
				cam.shake(0.35)
				target.gain_fury(20)
				if ui and target == P: ui.toast("APARADO!", Color(1, 0.88, 0.55))
				if post: post.impact_frames(0.05, Color(1.0, 0.95, 0.8))
				fx.impact(target.global_position + Vector3(0, 1.3, 0) - dir * 0.5, Color(1, 0.9, 0.6), 2.0)
				if target is Player and target.fk:
					target.fk.on_parry(src)
				return false
			target.stamina = max(0.0, target.stamina - amount * 1.6)
			Audio.sfx("block")
			fx.burst("spark", target.global_position + Vector3(0, 1.2, 0) - dir * 0.4, {"n": 10})
			target.knock += dir * 3.0
			if target.stamina <= 0.0:
				target.guard_break()
			else:
				amount *= 0.15
				if amount < 1.0:
					return true
	if target.resist.has(o.get("element", "")):
		amount *= target.resist[o.element]
	amount *= target.dmg_taken_mul
	amount *= float(o.get("dmg_mul", 1.0))
	if target is Player and target.fk:
		amount *= target.fk.incoming_mul(src, o)
	if target is Player and target.versus:
		amount *= VERSUS_DMG
	amount = round(amount * (1.5 if o.get("crit", false) else 1.0))
	if target.min_hp >= 0.0:
		amount = min(amount, max(0.0, target.hp - target.min_hp))
	target.hp -= amount
	target.last_hit_by = src
	if target.rig:
		target.rig.flash(o.get("flash_col", Color(1, 1, 1)), 1.0)
	var hp_pos: Vector3 = target.global_position + Vector3(0, target.height * 0.6, 0)
	if o.get("fx", true):
		fx.burst("spark", hp_pos, {"n": 22 if o.get("heavy", false) else 12, "dir": dir, "color": o.get("spark", Color(1, 0.95, 0.75)), "color2": o.get("spark2", Color(1, 0.42, 0.06))})
		if target.bleeds:
			fx.burst("blood", hp_pos, {"n": 10 if o.get("heavy", false) else 5, "dir": dir})
	Audio.sfx("crit" if o.get("crit", false) else ("hitHeavy" if o.get("heavy", false) else "hit"), o.get("vol", 1.0))
	if ui:
		ui.damage_number(hp_pos, amount, o.get("crit", false), target == P, o.get("num_col", null))
	if src == P or (src and is_instance_valid(src) and (src.team == "player" or src is Player)):
		if o.get("fx", true) and (o.get("heavy", false) or o.get("crit", false) or o.get("finisher", false)):
			fx.impact(hp_pos - dir * 0.3, o.get("spark2", Color(1, 0.55, 0.2)).lerp(Color.WHITE, 0.3), 2.4 if o.get("finisher", false) else 1.5)
		hitstop = max(hitstop, o.get("hitstop", 0.09 if o.get("heavy", false) else 0.045))
		cam.shake(o.get("shake", 0.3 if o.get("heavy", false) else 0.13), dir)
		if src is Player:
			src.gain_fury(o.get("fury_gain", 3.5))
	if target == P:
		cam.shake(0.35 + min(0.4, amount / 60.0))
		if post: post.hurt = 0.5
	if target is Player:
		target.gain_fury(amount * 0.6)
	target.knock += dir * o.get("knock", 3.0) * target.knock_resist
	if o.get("launch", 0.0) > 0.0 and not target.big and target.alive:
		target.vy = o.launch
		fx.burst("dust", target.global_position, {"n": 8, "size": 0.7})
	target.on_hit(src, amount, o)
	if target.hp <= 0.0:
		target.hp = 0.0
		target.die(src)
	return true

# ---------------------------------------------------------------------
#  Ataques em área com aviso
# ---------------------------------------------------------------------
func in_shape(p: Vector3, s: Dictionary, extra := 0.0) -> bool:
	var dx: float = p.x - s.pos.x
	var dz: float = p.z - s.pos.z
	var d := sqrt(dx * dx + dz * dz)
	match s.shape:
		"circle":
			return d <= s.radius + extra and (d >= s.get("inner", 0.0) - extra)
		"cone":
			return d <= s.radius + extra and abs(ang_diff(atan2(dx, dz), s.yaw)) <= s.angle / 2.0 + 0.1
		"rect":
			var f: float = sin(s.yaw) * dx + cos(s.yaw) * dz
			var l: float = cos(s.yaw) * dx - sin(s.yaw) * dz
			return f >= -extra and f <= s.length + extra and abs(l) <= s.width / 2.0 + extra
	return false

func area_attack(o: Dictionary) -> Dictionary:
	var s := {"shape": o.get("shape", "circle"), "pos": o.pos, "radius": o.get("radius", 2.0), "angle": o.get("angle", 1.0), "yaw": o.get("yaw", 0.0), "width": o.get("width", 2.0), "length": o.get("length", 6.0), "inner": o.get("inner", 0.0)}
	var delay: float = o.get("delay", 0.0)
	var tel = null
	if delay > 0.0 and o.get("telegraph", true):
		tel = fx.telegraph(s, delay, o.get("color", Color(1, 0.16, 0.12)))
		Audio.sfx("telegraph", 0.6)
	var a := {"t": 0.0, "delay": delay, "s": s, "o": o, "tel": tel}
	areas.append(a)
	return a

func cancel_area(a: Dictionary) -> void:
	areas.erase(a)
	if a.get("tel") and is_instance_valid(a.tel):
		a.tel.queue_free()

func _update_areas(dt: float) -> void:
	var list := areas.duplicate()
	for a in list:
		a.t += dt
		if a.t >= a.delay:
			areas.erase(a)
			_trigger_area(a)

func _trigger_area(a: Dictionary) -> void:
	var s: Dictionary = a.s
	var o: Dictionary = a.o
	if a.tel and is_instance_valid(a.tel):
		a.tel.queue_free()
	if o.has("on_trigger") and o.on_trigger.is_valid():
		o.on_trigger.call(s)
	for t in actors.duplicate():
		if not is_instance_valid(t) or not t.alive or t.team == o.get("team", "enemy") or t.team == "neutral":
			continue
		if in_shape(t.global_position, s, t.radius * 0.6):
			damage(o.get("src"), t, o.get("dmg", 10.0), {"knock": o.get("knock", 6.0), "heavy": o.get("heavy", true), "from": o.get("from", s.pos), "element": o.get("element", ""), "unblockable": o.get("unblockable", false), "crit": o.get("crit", false), "fury_gain": o.get("fury_gain", 3.5), "fx": o.get("fx", true)})

# ---------------------------------------------------------------------
#  Projéteis
# ---------------------------------------------------------------------
func spawn_projectile(o: Dictionary) -> Dictionary:
	var node: Node3D = fx.projectile_visual(o.get("kind", "orb"), o)
	world.add_child(node)
	node.global_position = o.pos
	var p := {"node": node, "pos": o.pos, "vel": o.vel, "team": o.team, "dmg": o.dmg, "radius": o.get("radius", 0.4), "life": o.get("life", 3.0),
		"src": o.get("src"), "pierce": o.get("pierce", false), "hit": [], "homing": o.get("homing", 0.0), "target": o.get("target"),
		"trail": o.get("trail", Callable()), "on_hit": o.get("on_hit", Callable()), "on_expire": o.get("on_expire", Callable()), "gravity": o.get("gravity", 0.0),
		"knock": o.get("knock", 3.0), "element": o.get("element", ""), "heavy": o.get("heavy", false), "crit": o.get("crit", false), "fury_gain": o.get("fury_gain", 3.5)}
	projectiles.append(p)
	return p

func _update_projectiles(dt: float) -> void:
	for p in projectiles.duplicate():
		p.life -= dt
		var tgt = p.target
		if p.homing > 0.0 and tgt and is_instance_valid(tgt) and tgt.alive:
			var want: Vector3 = (tgt.global_position + Vector3(0, tgt.height * 0.6, 0) - p.pos).normalized() * p.vel.length()
			p.vel = p.vel.lerp(want, min(1.0, p.homing * dt))
		p.vel.y -= p.gravity * dt
		p.pos += p.vel * dt
		var node: Node3D = p.node
		if is_instance_valid(node):
			node.global_position = p.pos
			if p.vel.length_squared() > 0.01:
				node.look_at(p.pos + p.vel, Vector3.UP if abs(p.vel.normalized().y) < 0.98 else Vector3.RIGHT)
				if node.has_meta("spin"):
					node.rotate_object_local(Vector3.RIGHT, float(node.get_meta("spin")) * Game.time)
		if p.trail.is_valid():
			p.trail.call(p, dt)
		var dead: bool = p.life <= 0.0 or p.pos.y < -0.5
		if not dead and level and level.has_method("outside"):
			dead = level.outside(p.pos, 1.0)
		if not dead:
			for t in actors.duplicate():
				if not is_instance_valid(t) or not t.alive or t.team == p.team or t.team == "neutral" or p.hit.has(t):
					continue
				var h: float = t.height
				if dist2d(t.global_position, p.pos) < t.radius + p.radius and p.pos.y > t.global_position.y - 0.2 and p.pos.y < t.global_position.y + h + 0.3:
					p.hit.append(t)
					var ok := damage(p.src, t, p.dmg, {"knock": p.knock, "from": p.pos - Vector3(p.vel.x, 0, p.vel.z).normalized(), "element": p.element, "heavy": p.heavy, "crit": p.crit, "fury_gain": p.fury_gain})
					if p.on_hit.is_valid():
						p.on_hit.call(p, t, ok)
					if not p.pierce:
						dead = true
						break
		if dead:
			if p.on_expire.is_valid():
				p.on_expire.call(p)
			if is_instance_valid(node):
				node.queue_free()
			projectiles.erase(p)

# ---------------------------------------------------------------------
#  Zonas perigosas (fogo, chamas azuis, vento)
# ---------------------------------------------------------------------
func add_hazard(o: Dictionary) -> Dictionary:
	var h := {"pos": o.pos, "radius": o.get("radius", 1.5), "dps": o.get("dps", 10.0), "life": o.get("life", 5.0), "team": o.get("team", "enemy"), "t": 0.0, "tick": 0.0,
		"kind": o.get("kind", "fire"), "src": o.get("src"), "pull": o.get("pull", 0.0), "vel": o.get("vel", Vector3.ZERO), "follow": o.get("follow")}
	h.node = fx.hazard_visual(h.kind, h.radius)
	world.add_child(h.node)
	h.node.global_position = h.pos
	hazards.append(h)
	return h

func _update_hazards(dt: float) -> void:
	for h in hazards.duplicate():
		h.t += dt
		h.tick -= dt
		h.pos += h.vel * dt
		var f = h.follow
		if f and is_instance_valid(f) and f.alive:
			var to: Vector3 = f.global_position - h.pos
			to.y = 0
			if to.length() > 0.1:
				h.pos += to.normalized() * dt * 2.2
		if is_instance_valid(h.node):
			h.node.global_position = Vector3(h.pos.x, 0.02, h.pos.z)
			h.node.set_meta("fade", min(1.0, h.t * 3.0) * min(1.0, (h.life - h.t) * 2.0))
		for t in actors.duplicate():
			if not is_instance_valid(t) or not t.alive or t.team == h.team or t.team == "neutral":
				continue
			var d := dist2d(t.global_position, h.pos)
			if h.pull > 0.0 and d < h.radius * 2.2 and d > 0.3:
				var pull: Vector3 = (h.pos - t.global_position)
				pull.y = 0
				t.knock += pull.normalized() * h.pull * dt * 8.0
			if d < h.radius + t.radius * 0.5 and h.tick <= 0.0:
				damage(h.src if h.src and is_instance_valid(h.src) else t, t, h.dps * 0.33, {"knock": 0.5, "fx": false, "vol": 0.4, "unblockable": true, "num_col": Color(0.5, 0.7, 1.0) if h.kind == "blueflame" else Color(1, 0.63, 0.38)})
		if h.tick <= 0.0:
			h.tick = 0.33
		if h.t >= h.life:
			if is_instance_valid(h.node):
				h.node.queue_free()
			hazards.erase(h)

func clear_systems() -> void:
	for p in projectiles:
		if is_instance_valid(p.node): p.node.queue_free()
	for h in hazards:
		if is_instance_valid(h.node): h.node.queue_free()
	for a in areas:
		if a.tel and is_instance_valid(a.tel): a.tel.queue_free()
	projectiles = []; hazards = []; areas = []; timers = []
	attack_tokens = 0
