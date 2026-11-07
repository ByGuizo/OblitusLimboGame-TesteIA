extends SceneTree
func _init():
	var l: AnimationLibrary = load("res://assets/anims/lib_male.res")
	print(", ".join(l.get_animation_list()))
	quit()
