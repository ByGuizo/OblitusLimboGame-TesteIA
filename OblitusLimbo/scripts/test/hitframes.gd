extends SceneTree
func _init():
	var rig: CharRig = CharFactory.build("near", {})
	root.add_child.call_deferred(rig)
	await process_frame
	await process_frame
	if rig.tree: rig.tree.active = false
	var ap := rig.anim
	var sk := rig.skel
	for n in ["Sword_Regular_A","Sword_Regular_B","Sword_Regular_C","Sword_Heavy_Combo","Sword_Attack","Sword_Dash","NinjaJump_Start","NinjaJump_Land","Slide","Punch_Jab","Punch_Cross","Melee_Hook","OverhandThrow","Shield_Dash","Shield_OneShot","Spell_Simple_Shoot","Roll","Zombie_Scratch","Sword_Regular_Combo"]:
		var a := ap.get_animation(n)
		ap.play(n)
		var prev := {}
		var peaks := []
		var dt := 1.0 / 60.0
		var t := 0.0
		var best := []
		while t <= a.length:
			ap.seek(t, true)
			ap.advance(0)
			var sp := 0.0
			for b in ["hand_r", "hand_l", "foot_r", "foot_l"]:
				var p := sk.get_bone_global_pose(sk.find_bone(b)).origin
				if prev.has(b): sp = maxf(sp, (p - prev[b]).length() / dt)
				prev[b] = p
			best.append([t, sp])
			t += dt
		# picos locais acima de 60% do máximo
		var mx := 0.0
		for e in best: mx = maxf(mx, e[1])
		var out := []
		for i in range(2, best.size() - 2):
			if best[i][1] >= mx * 0.55 and best[i][1] >= best[i-1][1] and best[i][1] >= best[i+1][1] and best[i][1] >= best[i-2][1] and best[i][1] >= best[i+2][1]:
				out.append("%.2f" % best[i][0])
		print("%s len=%.2f peaks=%s max=%.1f" % [n, a.length, ", ".join(out), mx])
	quit()
