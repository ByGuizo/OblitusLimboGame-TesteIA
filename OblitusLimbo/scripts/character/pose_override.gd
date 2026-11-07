class_name PoseOverride
extends SkeletonModifier3D
## Aplica rotações extras (no espaço do modelo) em ossos, depois da animação.
## Usado para tocar ukulele, puxar o arco, inclinar o tronco e olhar para alvos.

var targets := {}        # bone_name -> {rot: Quaternion (delta global), w: float, goal: float}
var blend_speed := 8.0

func set_offset(bone: String, euler_deg: Vector3, weight := 1.0) -> void:
	var q := Quaternion.from_euler(euler_deg * PI / 180.0)
	if targets.has(bone):
		targets[bone].rot = q
		targets[bone].goal = weight
	else:
		targets[bone] = {"rot": q, "w": 0.0, "goal": weight}

func clear_all() -> void:
	for k in targets:
		targets[k].goal = 0.0

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := get_process_delta_time()
	for bone in targets.keys():
		var t: Dictionary = targets[bone]
		t.w = move_toward(t.w, t.goal, dt * blend_speed)
		if t.w <= 0.0005:
			continue
		var bi := sk.find_bone(bone)
		if bi < 0:
			continue
		var gp := sk.get_bone_global_pose(bi)
		var q: Quaternion = Quaternion.IDENTITY.slerp(t.rot, t.w)
		var new_basis := Basis(q) * gp.basis
		var parent := sk.get_bone_parent(bi)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var local := pg.basis.inverse() * new_basis
		sk.set_bone_pose_rotation(bi, local.get_rotation_quaternion())
