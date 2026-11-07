extends SceneTree
func _init():
	for n in ["nature/TwistedTree_1","nature/DeadTree_1","nature/Flower_3_Group","nature/Flower_4_Group","nature/Grass_Wispy_Tall","nature/Rock_Medium_1","nature/Bush_Common","nature/Clover_1","dungeon/pillar","dungeon/table_medium","dungeon/candle_lit","village/Stair_Interior_Rails"]:
		var s: Node3D = load("res://assets/%s.gltf" % n).instantiate()
		var out := []
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(i)
				out.append("%s:%s v=%d" % [mi.name, m.resource_name if m else "null", mi.mesh.surface_get_array_len(i)])
		print(n, " -> ", out)
		s.free()
	quit()
