extends SceneTree
## Retarget offline: converte as animações da Universal Animation Library (esqueleto do
## manequim) para os esqueletos dos trajes modulares (masculino e feminino), preservando a
## pose global relativa ao repouso. Gera res://assets/anims/lib_male.res e lib_female.res.

const FPS := 30.0

func skel_of(p: String) -> Skeleton3D:
	var s: Node = load(p).instantiate()
	return s.find_child("Skeleton3D", true, false)

func global_rest_rots(sk: Skeleton3D) -> Array:
	var out := []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_global_rest(i).basis.get_rotation_quaternion())
	return out

func retarget_lib(src_players: Array, src: Skeleton3D, dst: Skeleton3D, out_path: String) -> void:
	var n := src.get_bone_count()
	var map := []          # índice no destino para cada osso da fonte
	for i in n:
		map.append(dst.find_bone(src.get_bone_name(i)))
	var rs := global_rest_rots(src)
	var rt := global_rest_rots(dst)
	var parents := []
	for i in n:
		parents.append(src.get_bone_parent(i))
	var dparents := []
	for i in n:
		dparents.append(dst.get_bone_parent(map[i]) if map[i] >= 0 else -1)
	var src_pelvis_h := src.get_bone_global_rest(src.find_bone("pelvis")).origin.y
	var dst_pelvis_h := dst.get_bone_global_rest(dst.find_bone("pelvis")).origin.y
	var ratio := dst_pelvis_h / src_pelvis_h
	var lib := AnimationLibrary.new()
	for ap in src_players:
		for an in ap.get_animation_list():
			if an == "A_TPose" or lib.has_animation(an):
				continue
			var a: Animation = ap.get_animation(an)
			# trilhas por osso
			var rtrack := {}
			var ptrack := -1
			for t in a.get_track_count():
				var bn := str(a.track_get_path(t)).get_slice(":", 1)
				var bi := src.find_bone(bn)
				if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					rtrack[bi] = t
				elif a.track_get_type(t) == Animation.TYPE_POSITION_3D and bn == "pelvis":
					ptrack = t
			var out := Animation.new()
			out.length = a.length
			out.loop_mode = Animation.LOOP_LINEAR if (an.ends_with("_Loop") or an in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "Crouch_Idle", "Sitting_Idle", "Sitting_Talking", "Spell_Simple_Idle", "Swim_Idle", "Swim_Fwd", "Idle_Talking", "Idle_Torch", "Pistol_Idle", "Dance", "Walk_Formal", "Crouch_Fwd", "Driving", "Push", "Idle_FoldArms", "Idle_Lantern", "Idle_Rail", "Idle_Shield", "Idle_TalkingPhone", "NinjaJump_Idle", "Slide", "TreeChopping", "Walk_Carry", "Zombie_Idle", "Zombie_Walk_Fwd", "Jump"]) else Animation.LOOP_NONE
			var dtracks := {}
			for i in n:
				if map[i] < 0:
					continue
				var tr := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(tr, NodePath("Armature/Skeleton3D:" + src.get_bone_name(i)))
				dtracks[i] = tr
			var ppos := out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(ppos, NodePath("Armature/Skeleton3D:pelvis"))
			var frames := int(ceil(a.length * FPS)) + 1
			for f in frames:
				var time := min(f / FPS, a.length)
				var gs := []
				gs.resize(n)
				var gt := []
				gt.resize(n)
				for i in n:
					var q: Quaternion
					if rtrack.has(i):
						q = a.rotation_track_interpolate(rtrack[i], time)
					else:
						q = src.get_bone_rest(i).basis.get_rotation_quaternion()
					var p: int = parents[i]
					gs[i] = (gs[p] * q) if p >= 0 else q
					gt[i] = gs[i] * rs[i].inverse() * rt[map[i]] if map[i] >= 0 else Quaternion.IDENTITY
				for i in n:
					if not dtracks.has(i):
						continue
					var p: int = parents[i]
					var local: Quaternion = (gt[p].inverse() * gt[i]) if p >= 0 else gt[i]
					out.rotation_track_insert_key(dtracks[i], time, local.normalized())
				var pp := Vector3(0, dst_pelvis_h, 0)
				if ptrack >= 0:
					pp = a.position_track_interpolate(ptrack, time)
					pp *= ratio
				out.position_track_insert_key(ppos, time, pp)
			out.optimize(0.002, 0.002, 4)
			lib.add_animation(an, out)
	var err := ResourceSaver.save(lib, out_path)
	print("saved ", out_path, " anims=", lib.get_animation_list().size(), " err=", err)

func _init():
	var s1: Node = load("res://assets/anims/UAL1_Standard.glb").instantiate()
	var s2: Node = load("res://assets/anims/UAL2_Standard.glb").instantiate()
	var src: Skeleton3D = s1.find_child("Skeleton3D", true, false)
	var players := [s1.find_child("AnimationPlayer", true, false), s2.find_child("AnimationPlayer", true, false)]
	retarget_lib(players, src, skel_of("res://assets/characters/Male_Ranger.gltf"), "res://assets/anims/lib_male.res")
	retarget_lib(players, src, skel_of("res://assets/characters/Female_Ranger.gltf"), "res://assets/anims/lib_female.res")
	retarget_lib(players, src, src, "res://assets/anims/lib_mannequin.res")
	quit()
