class_name CharRig
extends Node3D
## Personagem montado: modelo + esqueleto + animações + cabeça/cabelo/acessórios + capas.

signal action_event(name: String)
signal action_finished(name: String)

var id := ""
var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var pose: PoseOverride
var mats: Array = []          # materiais com parâmetros flash/dissolve
var head_mat: ShaderMaterial
var head_node: Node3D
var height := 1.85
var cloths: Array = []
var attach := {}
var weapon: Node3D
var weapon2: Node3D
var ukulele: Node3D
var ukulele_back := Transform3D()
var ukulele_front := Transform3D()
var spec := {}

var loco_anim := ""
var action := ""
var action_hold := false
var action_events: Array = []
var action_loop := false
var action_upper := false
var on_event: Callable
var on_end: Callable
var _flash := 0.0
var _flash_col := Color.WHITE
var combat := false
var face_angry := false
var dissolve := 0.0

const LOCO := {"idle": "Idle", "combat": "Sword_Idle", "walk": "Walk", "jog": "Jog_Fwd", "sprint": "Sprint"}

func _ready() -> void:
	if anim and tree == null:
		_build_tree()
	Toon.convert_tree(self, true, 0.6)

# ---------------------------------------------------------------------
#  Anexos
# ---------------------------------------------------------------------
## Anexa um nó a um osso, posicionado no espaço de repouso do modelo (Y pra cima, +Z frente).
func attach_model(node: Node3D, bone: String, model_xf: Transform3D) -> Node3D:
	var ba: BoneAttachment3D = attach.get(bone)
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.bone_name = bone
		skel.add_child(ba)
		attach[bone] = ba
	var bi := skel.find_bone(bone)
	var rest := skel.get_bone_global_rest(bi)
	ba.add_child(node)
	node.transform = rest.affine_inverse() * model_xf
	return node

func bone_world(bone: String) -> Vector3:
	var bi := skel.find_bone(bone)
	return skel.global_transform * skel.get_bone_global_pose(bi).origin

func bone_model_point(bone: String, model_point: Vector3) -> Vector3:
	var bi := skel.find_bone(bone)
	return skel.global_transform * (skel.get_bone_global_pose(bi) * (skel.get_bone_global_rest(bi).affine_inverse() * model_point))

# ---------------------------------------------------------------------
#  Animação
# ---------------------------------------------------------------------
func has_anim(n: String) -> bool:
	return anim and anim.has_animation(n)

# ---- AnimationTree: locomoção contínua + 2 slots de ação com crossfade ----
var tree: AnimationTree
var _slot := 0                  # slot ativo (0 = A, 1 = B)
var action_time := 0.0
var action_len := 1.0
var action_speed := 1.0
var _act_amt := 0.0             # mistura base ↔ ação
var _act_target := 0.0
var _act_rate := 12.0
var _combat_amt := 0.0
var _move_amt := 0.0
var _loco_speed := 0.0
var _sprint := false
var _frozen := false

func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var mk := func(n: String) -> AnimationNodeAnimation:
		var an := AnimationNodeAnimation.new()
		an.animation = n
		return an
	bt.add_node("idle", mk.call(LOCO.idle), Vector2(0, 0))
	bt.add_node("cidle", mk.call(LOCO.combat), Vector2(0, 120))
	var combat := AnimationNodeBlend2.new()
	bt.add_node("combat", combat, Vector2(200, 60))
	bt.connect_node("combat", 0, "idle")
	bt.connect_node("combat", 1, "cidle")
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 9.0
	bs.sync = true
	bs.add_blend_point(mk.call(LOCO.walk), 1.6, -1, &"walk")
	bs.add_blend_point(mk.call(LOCO.jog), 4.6, -1, &"jog")
	bs.add_blend_point(mk.call(LOCO.sprint), 7.5, -1, &"sprint")
	bt.add_node("loco", bs, Vector2(0, 260))
	var lts := AnimationNodeTimeScale.new()
	bt.add_node("loco_ts", lts, Vector2(200, 260))
	bt.connect_node("loco_ts", 0, "loco")
	var move := AnimationNodeBlend2.new()
	move.sync = false
	bt.add_node("move", move, Vector2(400, 150))
	bt.connect_node("move", 0, "combat")
	bt.connect_node("move", 1, "loco_ts")
	# slots de ação
	var tr := AnimationNodeTransition.new()
	tr.add_input("A")
	tr.add_input("B")
	tr.set_input_reset(0, true)
	tr.set_input_reset(1, true)
	tr.xfade_time = 0.08
	bt.add_node("slots", tr, Vector2(400, 400))
	for k in ["a", "b"]:
		bt.add_node(k + "_anim", mk.call(LOCO.idle), Vector2(0, 400 + (0 if k == "a" else 140)))
		bt.add_node(k + "_seek", AnimationNodeTimeSeek.new(), Vector2(150, 400 + (0 if k == "a" else 140)))
		bt.add_node(k + "_ts", AnimationNodeTimeScale.new(), Vector2(280, 400 + (0 if k == "a" else 140)))
		bt.connect_node(k + "_seek", 0, k + "_anim")
		bt.connect_node(k + "_ts", 0, k + "_seek")
	bt.connect_node("slots", 0, "a_ts")
	bt.connect_node("slots", 1, "b_ts")
	var act := AnimationNodeBlend2.new()
	bt.add_node("act", act, Vector2(600, 250))
	bt.connect_node("act", 0, "move")
	bt.connect_node("act", 1, "slots")
	bt.connect_node("output", 0, "act")
	tree = AnimationTree.new()
	tree.name = "Tree"
	anim.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.tree_root = bt
	tree.active = true

func _p(path: String, v) -> void:
	tree.set("parameters/" + path, v)

## Locomoção: velocidade contínua → blend space sincronizado (sem trocas bruscas de clipe).
func set_loco(speed: float, sprint := false, _idle_override := "") -> void:
	_loco_speed = speed
	_sprint = sprint

## Toca uma ação. opts: speed, blend, fade_out, events {t:nome}, on_event, on_end, hold, loop, from, freeze_end
func play(n: String, opts := {}) -> void:
	if not has_anim(n):
		push_warning("animação inexistente: " + n)
		return
	if tree == null:
		_build_tree()
	action = n
	action_hold = opts.get("hold", false)
	action_loop = opts.get("loop", false)
	on_event = opts.get("on_event", Callable())
	on_end = opts.get("on_end", Callable())
	action_events = []
	var ev: Dictionary = opts.get("events", {})
	for k in ev:
		action_events.append([float(k), ev[k], false])
	var a := anim.get_animation(n)
	action_len = a.length
	action_speed = opts.get("speed", 1.0)
	action_time = opts.get("from", 0.0)
	_frozen = false
	var blend: float = opts.get("blend", 0.1)
	# usa o outro slot para fazer crossfade com a ação anterior
	var was_acting := _act_amt > 0.05
	_slot = 1 - _slot
	var k := "a" if _slot == 0 else "b"
	var bt: AnimationNodeBlendTree = tree.tree_root
	(bt.get_node(k + "_anim") as AnimationNodeAnimation).animation = n
	(bt.get_node("slots") as AnimationNodeTransition).xfade_time = blend if was_acting else 0.0
	_p("slots/transition_request", "A" if _slot == 0 else "B")
	_p(k + "_seek/seek_request", action_time)
	_p(k + "_ts/scale", action_speed)
	_act_target = 1.0
	_act_rate = 1.0 / maxf(blend, 0.016)
	if opts.get("freeze_end", false):
		_freeze()
		_act_amt = 1.0

func _freeze() -> void:
	var k := "a" if _slot == 0 else "b"
	action_time = action_len - 0.02
	_p(k + "_seek/seek_request", action_time)
	_p(k + "_ts/scale", 0.0)
	_frozen = true

## Muda a velocidade da ação atual (ex.: câmera lenta local, golpes acelerados).
func set_action_speed(v: float) -> void:
	action_speed = v
	if tree and not _frozen:
		_p(("a" if _slot == 0 else "b") + "_ts/scale", v)

func stop_action(blend := 0.2) -> void:
	if action == "":
		return
	action = ""
	action_hold = false
	_frozen = false
	_act_target = 0.0
	_act_rate = 1.0 / maxf(blend, 0.016)

func is_busy() -> bool:
	return action != ""

func action_pos() -> float:
	return action_time if action != "" else 0.0

func _finish_action() -> void:
	var n := action
	if action_loop:
		action_time = 0.0
		_p(("a" if _slot == 0 else "b") + "_seek/seek_request", 0.0)
		for e in action_events: e[2] = false
		return
	if action_hold:
		_freeze()
		return
	var cb := on_end
	stop_action(0.18)
	action_finished.emit(n)
	if cb.is_valid():
		cb.call()

func _process(delta: float) -> void:
	if tree == null and anim:
		_build_tree()
	if tree:
		# locomoção
		_combat_amt = move_toward(_combat_amt, 1.0 if combat else 0.0, delta * 3.0)
		var spd := _loco_speed
		var moving := clampf((spd - 0.15) / 1.0, 0.0, 1.0)
		_move_amt = lerpf(_move_amt, moving, 1.0 - exp(-delta * 14.0))
		_p("combat/blend_amount", _combat_amt)
		_p("move/blend_amount", _move_amt)
		var bp := clampf(spd, 1.6, 7.5)
		_p("loco/blend_position", bp)
		var rate := 1.0
		if spd < 1.6:
			rate = clampf(spd / 1.6, 0.7, 1.0)
		elif spd > 7.5:
			rate = spd / 7.5
		_p("loco_ts/scale", rate)
		# ação
		_act_amt = move_toward(_act_amt, _act_target, delta * _act_rate)
		_p("act/blend_amount", _act_amt)
		if action != "" and not _frozen:
			action_time += delta * action_speed
			for e in action_events:
				if not e[2] and action_time >= e[0]:
					e[2] = true
					action_event.emit(e[1])
					if on_event.is_valid():
						on_event.call(e[1])
			if action_time >= action_len - 0.001 and action != "":
				_finish_action()
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 8.0)
		_apply_flash()

# ---------------------------------------------------------------------
#  Efeitos de material
# ---------------------------------------------------------------------
func flash(col := Color.WHITE, amount := 1.0) -> void:
	_flash_col = col
	_flash = amount
	_apply_flash()

func _apply_flash() -> void:
	var v := Vector4(_flash_col.r, _flash_col.g, _flash_col.b, _flash * 0.8)
	for m in mats:
		m.set_shader_parameter("flash", v)

func set_dissolve(v: float) -> void:
	dissolve = v
	for m in mats:
		m.set_shader_parameter("dissolve", v)
		if m.next_pass:
			m.next_pass.set_shader_parameter("dissolve", v)

## Escurece/clareia o personagem inteiro (corrupção, sombras). 1 = normal.
func set_tint(f, col := Color.WHITE) -> void:
	var c := Color(col.r * f, col.g * f, col.b * f)
	for mi in find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = mi
		var m = gi.material_override
		if m is ShaderMaterial:
			m.set_shader_parameter("shade_tint", c)
		if gi is MeshInstance3D:
			for si in (gi as MeshInstance3D).get_surface_override_material_count():
				var sm = (gi as MeshInstance3D).get_surface_override_material(si)
				if sm is ShaderMaterial:
					sm.set_shader_parameter("shade_tint", c)
	for m in mats:
		if m is ShaderMaterial:
			m.set_shader_parameter("shade_tint", c)

func set_face(angry: bool) -> void:
	face_angry = angry
	if head_mat:
		var tw := create_tween()
		tw.tween_method(func(x): head_mat.set_shader_parameter("face_mix", x), 1.0 - float(angry), float(angry), 0.15)

func set_eye_glow(c: Color) -> void:
	if head_mat:
		head_mat.set_shader_parameter("eye_glow", Vector3(c.r, c.g, c.b))

func set_cloth_active(v: bool) -> void:
	for c in cloths:
		c.set_active(v)

func reset_cloth() -> void:
	for c in cloths:
		c.reset()
