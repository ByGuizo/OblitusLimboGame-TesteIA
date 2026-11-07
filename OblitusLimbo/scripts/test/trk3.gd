extends SceneTree
func _init():
	var s2: Node = load("res://assets/anims/UAL2_Standard.glb").instantiate()
	var s1: Node = load("res://assets/anims/UAL1_Standard.glb").instantiate()
	var src: Skeleton3D = s1.find_child("Skeleton3D", true, false)
	var src2: Skeleton3D = s2.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = s2.find_child("AnimationPlayer", true, false)
	var a := ap.get_animation("Fixing_Kneeling")
	print("has in UAL1? ", (s1.find_child("AnimationPlayer", true, false) as AnimationPlayer).has_animation("Fixing_Kneeling"))
	var bi := src.find_bone("thigh_l")
	print("src1 thigh idx ", bi, " src2 idx ", src2.find_bone("thigh_l"), " parent ", src.get_bone_parent(bi), " name ", src.get_bone_name(src.get_bone_parent(bi)))
	for t in a.get_track_count():
		var p := str(a.track_get_path(t))
		if p.contains("thigh_l") or p.contains("pelvis"):
			print(t, " ", p, " type=", a.track_get_type(t), " keys=", a.track_get_key_count(t), " v@1=", a.rotation_track_interpolate(t, 1.0) if a.track_get_type(t) == Animation.TYPE_ROTATION_3D else a.position_track_interpolate(t, 1.0))
	print("rest1 thigh ", src.get_bone_rest(bi).basis.get_rotation_quaternion(), " rest2 ", src2.get_bone_rest(src2.find_bone("thigh_l")).basis.get_rotation_quaternion())
	print("bones1=", src.get_bone_count(), " bones2=", src2.get_bone_count(), " b1[1..4]=", [src.get_bone_name(1), src.get_bone_name(2), src.get_bone_name(3), src.get_bone_name(4)])
	quit()
