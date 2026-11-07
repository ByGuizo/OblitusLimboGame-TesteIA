extends Node3D
var n: Npc
var t := 0.0
func _ready():
	Game.world = self
	var fx := FX.new(); add_child(fx); Game.fx = fx
	await get_tree().process_frame
	n = Npc.new()
	n.setup_npc("kiana", {"pos": Vector3.ZERO})
	add_child(n)
	n.rig.play("Fixing_Kneeling", {"loop": true})
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(2.5, 1.6, 2.5); cam.look_at(Vector3(0, 0.4, 0))
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.3, 0.3, 0.35); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.6, 0.7); we.environment = e; add_child(we)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); cs.shape = WorldBoundaryShape3D.new(); sb.add_child(cs); add_child(sb)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10, 10); fl.mesh = pm; add_child(fl)
	var rn: Node = n.rig.anim.get_node(n.rig.anim.root_node)
	print("rootnode=", rn.name, " children=", rn.get_children().map(func(c): return c.name), " skel_path_ok=", rn.get_node_or_null("Armature/Skeleton3D") != null, " rig.skel path=", rn.get_path_to(n.rig.skel))
	print("after pose: action=", n.rig.action, " cur=", n.rig.anim.current_animation, " playing=", n.rig.anim.is_playing())
func _process(d):
	if n == null: return
	t += d
	if int(t * 10) != int((t - d) * 10):
		var sk: Skeleton3D = n.rig.skel
		var hb := sk.find_bone("Head")
		if t < 0.6: print([sk.get_bone_name(0), sk.get_bone_name(1), sk.get_bone_name(2), sk.get_bone_name(3)], " anim tracks: ", n.rig.anim.get_animation("Death01").get_track_count(), " ", n.rig.anim.get_animation("Death01").track_get_path(0), " ", n.rig.anim.get_animation("Death01").track_get_path(1))
		print("t=%.2f action=%s cur=%s asg=%s pos=%.2f playing=%s spd=%.2f active=%s head_y=%.2f root=%s libs=%s" % [t, n.rig.action, n.rig.anim.current_animation, n.rig.anim.assigned_animation, n.rig.anim.current_animation_position, n.rig.anim.is_playing(), n.rig.anim.speed_scale, n.rig.anim.active, sk.get_bone_global_pose(hb).origin.y, n.rig.anim.root_node, n.rig.anim.get_animation_library_list()])
	if t > 3.5: get_tree().quit()
