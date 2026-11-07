extends SceneTree
func _init():
	var l: AnimationLibrary = load("res://assets/anims/lib_female.res")
	var a := l.get_animation("Fixing_Kneeling")
	var out := []
	for i in a.get_track_count():
		var p := String(a.track_get_path(i))
		var tp := a.track_get_type(i)
		var n := a.track_get_key_count(i)
		var v0 = a.track_get_key_value(i, 0) if n > 0 else null
		var v1 = a.track_get_key_value(i, n / 2) if n > 0 else null
		if p.contains("pelvis") or p.contains("thigh") or p.contains("calf") or p.contains("root") or p.contains("spine_01"):
			out.append("%s type=%d keys=%d v0=%s vmid=%s" % [p.get_slice(":", 1), tp, n, v0, v1])
	print("\n".join(out))
	print("total tracks ", a.get_track_count())
	quit()
