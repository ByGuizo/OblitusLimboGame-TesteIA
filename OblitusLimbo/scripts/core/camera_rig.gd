class_name CameraRig
extends Node3D
## Câmera dinâmica (porte de camera.js): ombro, trava de alvo, colisão, tremor, FOV, cinemáticas.

var cam: Camera3D
var yaw := 0.0
var pitch := 0.22
var dist := 4.4
var trauma := 0.0
var fov_kick := 0.0
var fov_base := 62.0
var sens := 1.0
var invert_y := false
var mode := "follow"
var pivot := Vector3.ZERO
var look := Vector3.ZERO
var shot_q = null
var blend_back := 0.0
var blend_t := 0.0
var blend_from := {}
var t := 0.0
var _mdx := 0.0
var _mdy := 0.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = fov_base
	cam.near = 0.08
	cam.far = 500.0
	add_child(cam)
	cam.current = true
	_make_outline()
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS

var _punch := Vector3.ZERO
var cur_roll := 0.0

## Tremor por trauma; `dir` (opcional) empurra a câmera no sentido do golpe.
var outline_quad: MeshInstance3D

func _make_outline() -> void:
	outline_quad = Toon.make_outline_quad(cam)
	apply_quality()

## Contornos em tela: desligados em Baixa, mais grossos em Alta.
const OUTLINE_HQ := preload("res://shaders/outline_post_hq.gdshader")
const OUTLINE_LQ := preload("res://shaders/outline_post.gdshader")

func apply_quality() -> void:
	if outline_quad == null:
		return
	var q: String = Save.opts.get("quality", "med")
	# contorno só por profundidade é barato (todas as qualidades); o de normais (vincos internos)
	# exige o buffer de normais em todo o cenário e fica só no Alto
	var m: ShaderMaterial = outline_quad.material_override
	m.shader = OUTLINE_HQ if q == "high" else OUTLINE_LQ
	m.set_shader_parameter("thickness", 1.25 if q == "high" else 1.0)

func shake(a: float, dir := Vector3.ZERO) -> void:
	trauma = min(1.0, trauma + a)
	if dir != Vector3.ZERO:
		_punch += dir.normalized() * a * 0.35

func kick(f: float) -> void:
	fov_kick = max(fov_kick, f)

func snap_behind(y: float) -> void:
	yaw = y
	pitch = 0.2

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mdx += e.relative.x
		_mdy += e.relative.y

static func _ease(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0

## Tomada cinematográfica: {pos, look, pos2, look2, dur, blend, fov, fov2, track: Callable(t)->{pos,look}, cut}
func shot(o: Dictionary) -> void:
	mode = "cine"
	shot_q = {"from_pos": cam.global_position, "from_look": look, "from_fov": cam.fov,
		"pos": o.pos, "look": o.look, "pos2": o.get("pos2", o.pos), "look2": o.get("look2", o.look),
		"blend": 0.0001 if o.get("cut", false) else o.get("blend", 0.6), "dur": o.get("dur", 3.0), "t": 0.0,
		"fov": o.get("fov", 50.0), "fov2": o.get("fov2", o.get("fov", 50.0)), "track": o.get("track", Callable()),
		"roll": o.get("roll", 0.0)}

func release(blend := 0.8) -> void:
	if mode != "cine":
		return
	mode = "follow"
	blend_back = blend
	blend_t = 0.0
	blend_from = {"pos": cam.global_position, "look": look}
	shot_q = null

func _process(delta: float) -> void:
	var rdt: float = Game.real_dt() if not get_tree().paused else 0.0
	t += rdt
	if _has_base:
		cam.global_position = _last_base
	var P = Game.player
	var desired_pos := cam.global_position
	var desired_look := look
	var fov := fov_base
	if mode == "cine" and shot_q != null:
		var s: Dictionary = shot_q
		s.t += rdt
		var tb: float = min(1.0, s.t / max(s.blend, 0.0001))
		var td: float = min(1.0, s.t / max(s.dur, 0.0001))
		var p: Vector3 = s.pos.lerp(s.pos2, _ease(td))
		var l: Vector3 = s.look.lerp(s.look2, _ease(td))
		if s.track.is_valid():
			var r: Dictionary = s.track.call(s.t)
			p = r.get("pos", p); l = r.get("look", l)
		var e := _ease(tb)
		desired_pos = s.from_pos.lerp(p, e)
		desired_look = s.from_look.lerp(l, e)
		if Game.versus:
			# Versus: cenas do Ultimate não atravessam mesas, pilares e paredes
			var space := get_world_3d().direct_space_state
			var rq := PhysicsRayQueryParameters3D.create(desired_look, desired_pos, 1)
			var rh := space.intersect_ray(rq)
			if rh:
				desired_pos = rh.position + (desired_look - desired_pos).normalized() * 0.35 + Vector3(0, 0.5, 0)
		fov = lerp(s.from_fov, lerp(s.fov, s.fov2, td), e)
		cam.global_position = desired_pos
		look = desired_look
	elif P and is_instance_valid(P):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
			yaw -= _mdx * 0.0024 * sens
			pitch = clamp(pitch + _mdy * 0.0019 * sens * (-1.0 if invert_y else 1.0), -0.3, 1.0)
		var tgt = P.lock_target if P.get("lock_target") and is_instance_valid(P.lock_target) and P.lock_target.alive else null
		var d := dist + (0.5 if P.sprinting else 0.0)
		if tgt:
			var big := 1.6 if tgt.big else 0.0
			var want := Game.yaw_to(P.global_position, tgt.global_position)
			yaw += Game.ang_diff(want, yaw) * (1.0 - exp(-rdt * 6.0))
			var dd := Game.dist2d(tgt.global_position, P.global_position)
			var want_pitch: float = clamp(0.2 + big * 0.08 - dd * 0.004, 0.1, 0.5)
			pitch += (want_pitch - pitch) * (1.0 - exp(-rdt * 3.0))
			d += 0.6 + big
		elif P.get("boss_near"):
			d += 1.2
		var f := Game.fwd(yaw)
		var right := Vector3(-cos(yaw), 0, sin(yaw))
		var pv: Vector3 = P.global_position + Vector3(0, P.height * 0.82, 0)
		pivot = pivot.lerp(pv, 1.0 - exp(-rdt * 14.0))
		var shoulder := 0.55
		desired_pos = pivot - f * cos(pitch) * d + right * shoulder + Vector3(0, sin(pitch) * d, 0)
		desired_look = pivot + right * shoulder * 0.7 + f * 2.5 - Vector3(0, 0.15, 0)
		if tgt:
			desired_look = desired_look.lerp(tgt.global_position + Vector3(0, 1.6 if tgt.big else 1.0, 0), 0.35)
		# colisão com o cenário
		var space := get_world_3d().direct_space_state
		var from := pivot + right * shoulder * 0.5
		var q := PhysicsRayQueryParameters3D.create(from, desired_pos, 1)
		var hit := space.intersect_ray(q)
		if hit:
			desired_pos = hit.position + (from - desired_pos).normalized() * 0.3
		if Game.level and Game.level.has_method("cam_clamp"):
			desired_pos = Game.level.cam_clamp(desired_pos)
		desired_pos.y = max(desired_pos.y, 0.35)
		if blend_back > 0.0:
			blend_t += rdt
			var e := _ease(min(1.0, blend_t / blend_back))
			desired_pos = blend_from.pos.lerp(desired_pos, e)
			desired_look = blend_from.look.lerp(desired_look, e)
			if e >= 1.0:
				blend_back = 0.0
			cam.global_position = desired_pos
			look = desired_look
		else:
			var k := 1.0 - exp(-rdt * 18.0)
			cam.global_position = cam.global_position.lerp(desired_pos, k)
			look = look.lerp(desired_look, k)
		fov = fov_base + (7.0 if P.sprinting else 0.0) + (-3.0 if tgt else 0.0)
	_mdx = 0.0
	_mdy = 0.0
	# tremor
	trauma = max(0.0, trauma - rdt * 1.6)
	var sh := trauma * trauma
	var tt := t * 40.0
	var off := Vector3(sin(tt * 1.1) + sin(tt * 2.3) * 0.5, sin(tt * 1.7 + 3.0) + sin(tt * 3.1) * 0.4, sin(tt * 1.3 + 7.0)) * sh * 0.22
	_punch = _punch.lerp(Vector3.ZERO, 1.0 - exp(-rdt * 14.0))
	off += _punch
	fov_kick = max(0.0, fov_kick - rdt * 30.0)
	cam.fov += ((fov + fov_kick) - cam.fov) * (1.0 - exp(-rdt * 8.0))
	var base_pos := cam.global_position
	cam.global_position = base_pos + off * 0.6
	if (look - cam.global_position).length() > 0.01:
		cam.look_at(look + off, Vector3.UP)
	var want_roll: float = shot_q.get("roll", 0.0) if mode == "cine" and shot_q != null else 0.0
	cur_roll = want_roll if (mode == "cine" and shot_q != null and shot_q.blend < 0.01) else lerpf(cur_roll, want_roll, 1.0 - exp(-rdt * 8.0))
	cam.rotate_object_local(Vector3.FORWARD, sin(tt * 0.9) * sh * 0.05 + cur_roll)
	cam.global_position = base_pos + off * 0.6
	_last_base = base_pos
	_has_base = true

var _last_base := Vector3.ZERO
var _has_base := false

## Posiciona a câmera imediatamente atrás do jogador (sem interpolação).
func snap_to_player() -> void:
	var P = Game.player
	mode = "follow"
	shot_q = null
	blend_back = 0.0
	if P == null or not is_instance_valid(P):
		return
	yaw = P.yaw
	pitch = 0.2
	var f := Game.fwd(yaw)
	var right := Vector3(-cos(yaw), 0, sin(yaw))
	pivot = P.global_position + Vector3(0, P.height * 0.82, 0)
	var p := pivot - f * cos(pitch) * dist + right * 0.55 + Vector3(0, sin(pitch) * dist, 0)
	look = pivot + right * 0.38 + f * 2.5 - Vector3(0, 0.15, 0)
	cam.global_position = p
	cam.fov = fov_base
	_last_base = p
	_has_base = true
	cam.look_at(look, Vector3.UP)
