extends SceneTree
func _init():
	var s1: Node = load("res://assets/anims/UAL1_Standard.glb").instantiate()
	var src: Skeleton3D = s1.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = s1.find_child("AnimationPlayer", true, false)
	var a := ap.get_animation("Fixing_Kneeling") if ap.has_animation("Fixing_Kneeling") else null
	if a == null:
		var s2: Node = load("res://assets/anims/UAL2_Standard.glb").instantiate()
		ap = s2.find_child("AnimationPlayer", true, false)
		a = ap.get_animation("Fixing_Kneeling")
	var dst: Skeleton3D = (load("res://assets/characters/Female_Peasant.gltf").instantiate() as Node).find_child("Skeleton3D", true, false)
	var lib: AnimationLibrary = load("res://assets/anims/lib_female.res")
	var b := lib.get_animation("Fixing_Kneeling")
	for bn in ["root", "pelvis", "thigh_l", "calf_l", "spine_01"]:
		var t := -1
		for i in a.get_track_count():
			if str(a.track_get_path(i)).ends_with(":" + bn) and a.track_get_type(i) == Animation.TYPE_ROTATION_3D: t = i
		var tb := -1
		for i in b.get_track_count():
			if str(b.track_get_path(i)).ends_with(":" + bn) and b.track_get_type(i) == Animation.TYPE_ROTATION_3D: tb = i
		var sr := src.get_bone_rest(src.find_bone(bn)).basis.get_rotation_quaternion()
		var dr := dst.get_bone_rest(dst.find_bone(bn)).basis.get_rotation_quaternion()
		print(bn, " src_track=", t, " srest=", sr, " sanim=", a.rotation_track_interpolate(t, 1.0) if t >= 0 else "none", " | drest=", dr, " danim=", b.rotation_track_interpolate(tb, 1.0) if tb >= 0 else "none")
	print("src tracks sample: ", a.track_get_path(0), " ", a.track_get_path(1), " count=", a.get_track_count())
	quit()
