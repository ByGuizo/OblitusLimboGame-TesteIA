extends SceneTree
func _init():
	var lib: AnimationLibrary = load("res://assets/anims/lib_female.res")
	for an in ["Fixing_Kneeling", "Death01", "Walk"]:
		var b := lib.get_animation(an)
		for i in b.get_track_count():
			var p := str(b.track_get_path(i))
			if p.ends_with(":thigh_l") and b.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				print(an, " thigh_l keys=", b.track_get_key_count(i), " @0=", b.rotation_track_interpolate(i, 0.0), " @mid=", b.rotation_track_interpolate(i, b.length * 0.6))
	quit()
