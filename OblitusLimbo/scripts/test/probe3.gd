extends SceneTree
func _init():
	for n in ["nature/TwistedTree_1","nature/DeadTree_1","nature/CommonTree_1","nature/Pine_1","nature/Grass_Wispy_Tall","nature/Flower_3_Group","nature/Bush_Common"]:
		var s: Node3D = load("res://assets/%s.gltf" % n).instantiate()
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(i)
				if m is BaseMaterial3D:
					print(n, " ", m.resource_name, " transp=", m.transparency, " cull=", m.cull_mode, " tex=", m.albedo_texture.get_size() if m.albedo_texture else "none", " scissor=", m.alpha_scissor_threshold, " lods=", mi.mesh.surface_get_lod_count(i) if mi.mesh is ImporterMesh else (mi.mesh as ArrayMesh).surface_get_format(i))
		s.free()
	quit()
