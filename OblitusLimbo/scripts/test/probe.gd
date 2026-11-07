extends SceneTree
func _init():
	var dirs := {"nature": ["TwistedTree_1","TwistedTree_3","DeadTree_1","DeadTree_3","Grass_Wispy_Tall","Grass_Wispy_Short","Flower_3_Group","Flower_4_Group","Rock_Medium_1","Rock_Medium_2","Bush_Common","Plant_7_Big","Clover_1","Petal_1"],
		"village": ["Floor_WoodDark","Wall_UnevenBrick_Straight","Stair_Interior_Rails","Balcony_Simple_Straight","Floor_WoodDark_Half1","Prop_Support","Wall_Arch"],
		"dungeon": ["floor_tile_large","floor_wood_large_dark","wall","wall_arched","pillar","pillar_decorated","column","table_long","table_medium","table_small","chair","stool","barrel_large","barrel_small_stack","keg","shelves","shelf_large","stairs","stairs_wide","candle_triple","banner_patternA_blue","banner_thin_blue","floor_tile_small_decorated","rubble_large","crates_stacked","wall_pillar","ceiling_tile"]}
	for d in dirs:
		for n in dirs[d]:
			var p := "res://assets/%s/%s.gltf" % [d, n]
			if not ResourceLoader.exists(p):
				print("MISSING ", p); continue
			var s: Node3D = load(p).instantiate()
			var aabb := AABB(); var first := true
			for mi in s.find_children("*", "MeshInstance3D", true, false):
				var b: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
				aabb = b if first else aabb.merge(b); first = false
			print("%s/%s pos=%s size=%s" % [d, n, aabb.position.snapped(Vector3.ONE*0.01), aabb.size.snapped(Vector3.ONE*0.01)])
			s.free()
	quit()
