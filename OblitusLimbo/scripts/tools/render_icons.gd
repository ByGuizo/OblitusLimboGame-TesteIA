extends Node3D
## Renderiza os ícones de habilidade com os personagens e os efeitos reais do jogo.
## Uso: Godot --path OblitusLimbo res://scenes/render_icons.tscn  → assets/icons/skills/*.png

const OUT := "res://assets/icons/skills/"
var cam: Camera3D
var env: Environment
var holder: Node3D

# id: [personagem, animação, tempo, cor de fundo, efeito, enquadramento(dist, altura, yaw, alvo_y)]
const ICONS := {
	"blade": ["kiana", "Spell_Simple_Shoot", 0.26, Color(0.45, 0.2, 0.85), "crescent", [2.3, 0.25, 0.75, 0.25]],
	"wave": ["kiana", "Spell_Simple_Shoot", 0.34, Color(0.85, 0.55, 0.15), "shock_gold", [2.9, 1.2, 0.35, -0.2]],
	"blink": ["kiana", "Sword_Dash", 0.42, Color(0.75, 0.05, 0.15), "blink", [2.8, 0.4, 1.25, 0.0]],
	"fury": ["kiana", "Sword_Idle", 0.4, Color(0.7, 0.02, 0.08), "aura_red", [2.1, 0.25, 0.35, 0.3]],
	"harmonic": ["kiana", "Spell_Simple_Idle", 0.5, Color(0.15, 0.6, 0.8), "aura_harm", [2.1, 0.25, 0.4, 0.3]],
	"spear": ["viktor", "Spell_Simple_Shoot", 0.26, Color(0.2, 0.45, 0.85), "spear", [2.4, 0.2, 0.75, 0.4]],
	"forest": ["viktor", "Spell_Simple_Shoot", 0.3, Color(0.15, 0.4, 0.75), "forest", [3.3, 1.0, 0.45, -0.2]],
	"blackice": ["viktor", "Shield_Dash", 0.4, Color(0.1, 0.2, 0.5), "blackice", [2.9, 0.4, 1.0, 0.0]],
	"punch": ["viktor", "Melee_Hook", 0.22, Color(0.85, 0.35, 0.05), "fist", [2.1, 0.2, 0.75, 0.35]],
	"chakra": ["kiana", "Spell_Simple_Idle", 0.4, Color(0.35, 0.25, 0.85), "chakra", [2.3, 0.3, 0.3, 0.2]],
	"potion": ["", "", 0.0, Color(0.75, 0.1, 0.25), "potion", [1.5, 0.55, 0.0, 0.28]],
	# Viktor
	"stake": ["viktor", "Spell_Simple_Shoot", 0.26, Color(0.25, 0.55, 0.95), "stake", [2.4, 0.2, 0.75, 0.4]],
	# Near
	"knives": ["near", "OverhandThrow", 0.62, Color(0.35, 0.22, 0.7), "knives", [2.4, 0.25, 0.7, 0.35]],
	"veil": ["near", "Sword_Idle", 0.4, Color(0.18, 0.1, 0.35), "veil", [2.3, 0.25, 0.4, 0.25]],
	"smoke": ["near", "Roll", 0.35, Color(0.3, 0.28, 0.4), "smoke", [3.0, 0.7, 0.6, 0.0]],
	"near_ult": ["near", "Sword_Dash", 0.42, Color(0.45, 0.2, 0.85), "near_ult", [2.8, 0.4, 1.1, 0.0]],
	# Darin
	"vines": ["darin", "Spell_Simple_Shoot", 0.26, Color(0.15, 0.55, 0.25), "vines", [2.5, 0.25, 0.75, 0.35]],
	"pack": ["darin", "Idle_Shield_Break", 0.5, Color(0.1, 0.45, 0.25), "pack", [3.0, 0.6, 0.35, -0.35]],
	"pounce": ["darin", "NinjaJump_Start", 0.45, Color(0.2, 0.6, 0.3), "pounce", [2.8, 0.3, 0.9, 0.2]],
	"darin_ult": ["darin", "Zombie_Scratch", 0.7, Color(0.1, 0.5, 0.25), "darin_ult", [2.3, 0.25, 0.5, 0.3]],
	# Amnon
	"chargedarrow": ["amnon", "Pistol_Shoot", 0.2, Color(0.85, 0.35, 0.1), "chargedarrow", [2.4, 0.25, 0.85, 0.35]],
	"bottle": ["amnon", "OverhandThrow", 0.6, Color(0.7, 0.3, 0.08), "bottle", [2.8, 0.5, 0.7, 0.2]],
	"hellgrab": ["amnon", "Melee_Hook", 0.22, Color(0.75, 0.15, 0.05), "hellgrab", [2.2, 0.2, 0.7, 0.35]],
	"amnon_ult": ["amnon", "Pistol_Shoot", 0.2, Color(0.65, 0.2, 0.05), "amnon_ult", [3.2, 0.9, 0.6, 0.1]],
	# Calista
	"thread": ["calista", "Pistol_Shoot", 0.2, Color(0.6, 0.05, 0.15), "thread", [2.4, 0.25, 0.85, 0.35]],
	"needles": ["calista", "Spell_Simple_Shoot", 0.26, Color(0.5, 0.08, 0.15), "needles", [2.4, 0.25, 0.75, 0.35]],
	"windrune": ["calista", "NinjaJump_Start", 0.45, Color(0.55, 0.65, 0.8), "windrune", [3.0, 0.8, 0.5, 0.0]],
	"calista_ult": ["calista", "Pistol_Shoot", 0.2, Color(0.15, 0.12, 0.35), "calista_ult", [2.8, 0.6, 0.6, 0.2]],
	# Krauser
	"tentacles": ["krauser", "Spell_Simple_Shoot", 0.3, Color(0.35, 0.1, 0.5), "tentacles", [3.4, 0.7, 1.0, 0.0]],
	"breath": ["krauser", "Idle_Shield_Break", 0.5, Color(0.7, 0.25, 0.05), "breath", [2.6, 0.3, 1.0, 0.45]],
	"redcrystal": ["krauser", "Spell_Simple_Shoot", 0.26, Color(0.5, 0.05, 0.12), "redcrystal", [2.4, 0.25, 0.75, 0.4]],
	"krauser_ult": ["krauser", "Spell_Simple_Idle", 0.5, Color(0.3, 0.05, 0.45), "krauser_ult", [3.2, 0.6, 0.3, 0.1]],
	# Yuto
	"iaido": ["yuto", "Sword_Attack", 0.62, Color(0.5, 0.55, 0.7), "iaido", [2.8, 0.35, 1.2, 0.2]],
	"stance": ["yuto", "Sword_Block", 0.4, Color(0.35, 0.35, 0.42), "stance", [2.2, 0.25, 0.45, 0.3]],
	"xcut": ["yuto", "Sword_Attack", 0.5, Color(0.6, 0.62, 0.75), "xcut", [2.6, 0.25, 0.8, 0.35]],
	"yuto_ult": ["yuto", "Sword_Idle", 0.4, Color(0.15, 0.15, 0.18), "yuto_ult", [2.3, 0.25, 0.45, 0.3]],
}
var backdrop: MeshInstance3D
var bd_mat: ShaderMaterial

const BACKDROP := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 col : source_color;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = step(0.55, fract(sin(floor(a * 18.0) * 43.1) * 917.3)) * smoothstep(0.08, 0.5, r);
	vec3 c = mix(col * 1.1, col * 0.18, smoothstep(0.0, 0.62, r));
	c += col * rays * 0.35;
	ALBEDO = c;
}
"""

func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.55, 0.8)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.8
	env.tonemap_exposure = 0.85
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 0.7
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.75, 0.6, 1.0)
	add_child(rim)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	Toon.make_outline_quad(cam)
	var fx := FX.new()
	add_child(fx)
	Game.fx = fx
	Game.world = self
	RenderingServer.global_shader_parameter_set("toon_key", 0.2)
	backdrop = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(14, 14)
	backdrop.mesh = qm
	bd_mat = ShaderMaterial.new()
	bd_mat.shader = Shader.new()
	bd_mat.shader.code = BACKDROP
	backdrop.material_override = bd_mat
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in ICONS:
		await _render(id)
	print("ícones prontos")
	get_tree().quit()

func _render(id: String) -> void:
	var d: Array = ICONS[id]
	if holder:
		holder.queue_free()
	Game.fx.clear()
	holder = Node3D.new()
	add_child(holder)
	env.background_color = d[3] * 0.15
	bd_mat.set_shader_parameter("col", d[3])
	var rig: CharRig = null
	if d[0] != "":
		rig = CharFactory.build(d[0], {})
		holder.add_child(rig)
		await get_tree().process_frame
		rig.combat = true
		rig.play(d[1], {"loop": true, "blend": 0.0, "from": d[2]})
		rig.set_action_speed(0.0)
	var fr: Array = d[5]
	var yaw: float = fr[2]
	# enquadra pelo esqueleto (algumas poses deslocam o corpo)
	await get_tree().process_frame
	var tgt := Vector3(0, fr[3], 0)
	if rig:
		var neck := rig.bone_world("neck_01")
		var pel := rig.bone_world("pelvis")
		tgt = pel.lerp(neck, 0.5 + fr[3])
	cam.global_position = tgt + Vector3(sin(yaw) * fr[0], fr[1], cos(yaw) * fr[0])
	cam.look_at(tgt)
	# fundo radial atrás do alvo, de frente para a câmera
	backdrop.global_position = tgt - (cam.global_position - tgt).normalized() * 4.0
	backdrop.look_at(cam.global_position, Vector3.UP)
	backdrop.rotate_object_local(Vector3.UP, PI)
	await get_tree().process_frame
	_effect(d[4], rig)
	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var s := mini(img.get_width(), img.get_height())
	var side := int(s * 0.86)
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
	print("ícone ", id)

func _effect(kind: String, rig: CharRig) -> void:
	var fx: FX = Game.fx
	match kind:
		"crescent":
			var hand := rig.bone_world("hand_r")
			for k in range(-1, 2):
				var n := fx.projectile_visual("crescent", {"color": Color(0.7, 0.45, 1.0), "color2": Color(0.38, 0.92, 1.0), "scale": 0.55})
				holder.add_child(n)
				n.global_position = hand + Vector3(k * 0.28, abs(k) * 0.06, 0.45 + (1 - abs(k)) * 0.35)
				n.look_at(n.global_position + Vector3(k * 0.2, 0, 1), Vector3.UP)
			for k in 8:
				fx.emit("note", hand + Vector3(randf_range(-0.7, 0.7), randf_range(-0.4, 0.6), randf_range(0.0, 0.9)), Vector3(0, 0.2, 0), 3.0, 0.22, Color(0.6, 0.9, 1.0) if k % 2 else Color(0.85, 0.6, 1.0))
		"shock_gold":
			fx.shockwave(Vector3.ZERO, Color(1, 0.82, 0.45), 2.2, {"glow": Color(0.6, 0.4, 0.15), "life": 1.5, "debris": false})
			for k in 12:
				fx.emit("note", Vector3(cos(k * 0.52) * 1.1, randf_range(0.5, 1.7), sin(k * 0.52) * 1.1), Vector3(0, 0.2, 0), 3.0, 0.28, Color(1, 0.86, 0.5) if k % 2 else Color(0.5, 0.95, 1.0))
		"blink":
			_ghost_copy(rig, Vector3(-0.7, 0, -0.7), Color(1, 0.15, 0.3))
			_ghost_copy(rig, Vector3(-1.4, 0, -1.4), Color(0.6, 0.1, 0.4))
			fx.trail(rig, Color(1, 0.15, 0.25), 3.0)
			fx.burst("shadow", rig.bone_world("pelvis") + Vector3(-0.5, 0, -0.5), {"n": 10, "r": 0.4, "color": Color(0.2, 0.0, 0.06)})
			for k in 8:
				fx.emit("ember", Vector3(randf_range(-1.2, 0.3), randf_range(0.4, 1.6), randf_range(-1.2, 0.3)), Vector3(0.6, 0.2, 0.6), 3.0, 0.12, Color(1, 0.2, 0.3))
		"aura_red":
			fx.aura(holder, Color(0.9, 0.02, 0.08), Color(0.12, 0.0, 0.03), 1.6)
			rig.set_eye_glow(Color(3.0, 0.05, 0.02))
			rig.set_face(true)
		"aura_harm":
			fx.aura(holder, Color(0.2, 0.75, 1.0), Color(1.0, 0.8, 0.35), 0.9)
			for k in 10:
				fx.emit("note", Vector3(randf_range(-0.9, 0.9), randf_range(0.6, 2.0), randf_range(-0.3, 0.7)), Vector3(0, 0.25, 0), 3.0, 0.28, Color(1, 0.86, 0.5) if k % 2 else Color(0.5, 0.95, 1.0))
		"spear":
			var hand := rig.bone_world("hand_r")
			var n := fx.projectile_visual("spear", {"scale": 1.1})
			holder.add_child(n)
			n.global_position = hand + Vector3(0.0, 0.05, 0.75)
			n.look_at(n.global_position + Vector3(0, 0, 1), Vector3.UP)
			fx.burst("ice", n.global_position + Vector3(0, 0, 0.3), {"n": 8, "speed": 0.25})
			fx.burst("magic", n.global_position, {"n": 6, "color": Color(0.4, 0.7, 1.0), "speed": 0.2})
		"forest":
			for k in 9:
				var a := lerpf(-0.2, PI + 0.2, k / 8.0)
				var rr := randf_range(1.0, 1.5)
				fx.ice_spike(Vector3(cos(a) * rr, 0, sin(a) * rr * 0.6 + 0.5), {"h": randf_range(0.7, 1.4), "r": 0.2, "life": 30.0, "silent": true})
		"blackice":
			for k in 6:
				fx.ice_spike(Vector3(randf_range(-0.4, 0.4), 0, -k * 0.55 - 0.5), {"black": true, "h": randf_range(0.6, 1.2), "r": 0.18, "life": 30.0, "silent": true})
			_ghost_copy(rig, Vector3(0, 0, -1.0), Color(0.4, 0.8, 1.0))
		"fist":
			fx.aura(holder, Color(1.0, 0.35, 0.05), Color(1.0, 0.7, 0.3), 0.6)
			rig.attach_model(fx.glow_ball(Color(1.3, 0.6, 0.2), 0.06), "hand_r", Transform3D(Basis(), rig.skel.get_bone_global_rest(rig.skel.find_bone("hand_r")).origin))
			fx.burst("fire", rig.bone_world("hand_r"), {"n": 12, "r": 0.08, "size": 0.5})
		"chakra":
			fx.aura(holder, Color(0.5, 0.32, 1.0), Color(0.75, 0.65, 1.0), 0.6)
			for k in 12:
				var ang := randf() * TAU
				fx.emit("magic", Vector3(cos(ang) * randf_range(0.4, 0.9), randf_range(0.0, 2.0), sin(ang) * randf_range(0.4, 0.9)), Vector3(0, 0.2, 0), 3.0, 0.16, Color(0.7, 0.55, 1.0))
		"stake":
			var hand := rig.bone_world("hand_r")
			var n := fx.projectile_visual("spear", {"scale": 1.3})
			holder.add_child(n)
			n.global_position = hand + Vector3(0.0, 0.05, 0.8)
			n.look_at(n.global_position + Vector3(0, 0, 1), Vector3.UP)
			fx.burst("ice", n.global_position + Vector3(0, 0, 0.3), {"n": 12, "speed": 0.3})
		"knives":
			var hand := rig.bone_world("hand_r")
			for k in range(-1, 2):
				var n := fx.projectile_visual("knife", {"color": Color(0.6, 0.45, 1.0), "scale": 2.6})
				holder.add_child(n)
				n.global_position = hand + Vector3(k * 0.32, 0.25 - abs(k) * 0.08, 0.55 + (1 - abs(k)) * 0.2)
				n.look_at(n.global_position + Vector3(k * 0.3, 0, 1), Vector3.UP)
		"veil":
			fx.aura(holder, Color(0.35, 0.2, 0.8), Color(0.08, 0.04, 0.16), 1.2)
			fx.burst("shadow", Vector3(0, 1.0, 0), {"n": 30, "r": 0.6, "color": Color(0.1, 0.05, 0.18)})
			_ghost_copy(rig, Vector3(0.0, 0, -0.01), Color(0.45, 0.3, 0.9))
			rig.visible = false
		"smoke":
			fx.smoke_cloud(Vector3(0.6, 0, 0.6), 1.8, 30.0)
			_ghost_copy(rig, Vector3(-0.6, 0, -0.6), Color(0.55, 0.4, 1.0))
		"near_ult":
			_ghost_copy(rig, Vector3(-0.7, 0, -0.7), Color(0.55, 0.35, 1.0))
			_ghost_copy(rig, Vector3(0.7, 0, -0.4), Color(0.4, 0.2, 0.9))
			for k in 5:
				fx.slash(Vector3(randf_range(-0.6, 0.6), 1.1 + randf_range(-0.3, 0.3), 0.6), randf() * TAU, {"color": Color(0.6, 0.4, 1.0), "intensity": 3.0, "roll": randf_range(-1.5, 1.5), "life": 9.0})
		"vines":
			var hand := rig.bone_world("hand_r")
			fx.tether(hand, hand + Vector3(0.3, 0.1, 2.5), Color(0.3, 1.0, 0.5), 30.0, 0.04)
			for k in 10:
				fx.emit("magic", hand + Vector3(randf_range(-0.2, 0.5), randf_range(-0.2, 0.3), randf_range(0.2, 2.2)), Vector3.ZERO, 3.0, 0.2, Color(0.3, 1.0, 0.5))
		"pack":
			for k in 3:
				var w := fx.projectile_visual("wolf", {"scale": 1.5})
				holder.add_child(w)
				w.global_position = Vector3((k - 1) * 0.9, 0, 0.7 + (1 - abs(k - 1)) * 0.35)
				w.look_at(w.global_position + Vector3(0, 0, 1), Vector3.UP)
		"pounce":
			_ghost_copy(rig, Vector3(0, -0.3, -0.8), Color(0.3, 1.0, 0.5))
			fx.burst("magic", Vector3(0, 1.0, 0), {"n": 20, "color": Color(0.3, 1.0, 0.5)})
		"darin_ult":
			fx.aura(holder, Color(0.15, 0.95, 0.4), Color(0.7, 1.0, 0.75), 1.3)
			for k in 3:
				fx.slash(Vector3(0, 1.2 + (k - 1) * 0.15, 0.7), 0.0, {"color": Color(0.3, 1.0, 0.5), "intensity": 3.0, "roll": 0.78 if k % 2 else -0.78, "big": true, "life": 9.0})
		"chargedarrow":
			var hand := rig.bone_world("hand_l")
			var n := fx.projectile_visual("arrow", {"color": Color(1.0, 0.5, 0.15), "glow": true})
			holder.add_child(n)
			n.scale = Vector3(4.0, 4.0, 2.0)
			n.global_position = hand + Vector3(0.0, 0.0, 0.7)
			n.look_at(n.global_position + Vector3(0, 0, 1), Vector3.UP)
			fx.burst("fire", hand + Vector3(0, 0, 0.3), {"n": 16, "r": 0.1, "size": 0.7})
		"bottle":
			var b := fx.projectile_visual("bottle", {})
			holder.add_child(b)
			b.global_position = rig.bone_world("hand_r") + Vector3(0.1, 0.35, 0.35)
			b.scale = Vector3.ONE * 3.0
			fx.burst("fire", Vector3(0.6, 0.2, 1.6), {"n": 30, "r": 0.5, "size": 1.2, "up": 1.5})
		"hellgrab":
			fx.aura(holder, Color(1.0, 0.35, 0.05), Color(1.0, 0.75, 0.3), 0.7)
			fx.burst("fire", rig.bone_world("hand_r"), {"n": 24, "r": 0.12, "size": 0.8})
			fx.burst("fire", rig.bone_world("hand_l"), {"n": 16, "r": 0.12, "size": 0.7})
		"amnon_ult":
			for k in 9:
				var n := fx.projectile_visual("arrow", {"color": Color(1.0, 0.45, 0.15), "glow": true, "scale": 1.3})
				holder.add_child(n)
				var p := Vector3(randf_range(-1.5, 1.5), randf_range(1.6, 3.2), randf_range(0.2, 1.8))
				n.global_position = p
				n.look_at(p + Vector3(0, -1, 0.15), Vector3.RIGHT)
				fx.burst("fire", p + Vector3(0, 0.2, 0), {"n": 3, "r": 0.05, "size": 0.6})
		"thread":
			var hand := rig.bone_world("hand_l")
			var n := fx.projectile_visual("arrow", {"color": Color(1.0, 0.15, 0.25), "glow": true})
			holder.add_child(n)
			n.scale = Vector3(4.0, 4.0, 2.0)
			n.global_position = hand + Vector3(0.0, 0.0, 0.9)
			n.look_at(n.global_position + Vector3(0, 0, 1), Vector3.UP)
			for k in 4:
				fx.tether(hand + Vector3(0, 0, 0.9), hand + Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.5), randf_range(0.2, 1.4)), Color(1.0, 0.15, 0.25), 30.0, 0.01)
		"needles":
			var hand := rig.bone_world("hand_r")
			for k in 7:
				var n := fx.projectile_visual("needle", {"scale": 1.6})
				holder.add_child(n)
				n.global_position = hand + Vector3((k - 3) * 0.12, 0.0, 0.7)
				n.look_at(n.global_position + Vector3((k - 3) * 0.1, 0, 1), Vector3.UP)
		"windrune":
			fx.ring(Vector3.ZERO, {"color": Color(0.95, 0.95, 1.0), "r1": 1.6, "life": 30.0, "intensity": 2.0})
			fx.burst("wind", Vector3(0, 0.6, 0), {"n": 24, "r": 1.0})
			fx.cracks(Vector3.ZERO, 1.6, Color(1.0, 0.3, 0.4), 30.0)
		"calista_ult":
			for k in 12:
				var a := randf() * TAU
				fx.tether(Vector3(cos(a) * randf_range(0.5, 2.5), 6.0, sin(a) * randf_range(0.5, 2.5) + 1.0), Vector3(randf_range(-0.3, 0.3), 1.2, 1.0), Color(1.0, 0.15, 0.25), 30.0, 0.012)
			fx.glow_ball(Color(1.6, 1.6, 2.0), 0.3)
		"tentacles":
			for k in 4:
				fx.ground_tentacle(Vector3(-0.6 - k * 0.15, 0, 0.5 + k * 0.6), 2.2 + k * 0.2, 30.0, Vector3(0.3, 0, 0.2))
		"breath":
			var head := rig.bone_world("Head")
			for k in 14:
				var d := 0.3 + k * 0.17
				fx.burst("fire", head + Vector3(randf_range(-0.1, 0.1) * d, -0.1 - d * 0.15, d), {"n": 3, "r": 0.06 + d * 0.12, "size": 0.7 + d * 0.35, "speed": 0.2})
		"redcrystal":
			var hand := rig.bone_world("hand_r")
			var n := fx.projectile_visual("crystal", {})
			holder.add_child(n)
			n.global_position = hand + Vector3(0.0, 0.05, 0.6)
			n.scale = Vector3.ONE * 2.0
			fx.burst("magic", n.global_position, {"n": 16, "color": Color(1, 0.1, 0.2), "speed": 0.2})
		"krauser_ult":
			fx.ring(Vector3(0, 0.05, 0), {"color": Color(0.7, 0.15, 1.0), "r1": 2.2, "life": 30.0, "intensity": 3.0})
			for k in 4:
				var a := k * TAU / 4.0 + 0.4
				fx.ground_tentacle(Vector3(cos(a) * 1.3, 0, sin(a) * 1.3), 2.8, 30.0, Vector3(-cos(a), 0, -sin(a)) * 0.6)
			fx.aura(holder, Color(0.5, 0.1, 0.8), Color(1.0, 0.2, 0.4), 1.0)
		"iaido":
			_ghost_copy(rig, Vector3(-0.8, 0, -0.9), Color(0.75, 0.8, 0.95))
			_ghost_copy(rig, Vector3(-1.6, 0, -1.8), Color(0.55, 0.6, 0.75))
			fx.slash(Vector3(0.2, 1.1, 0.6), 0.0, {"color": Color(0.9, 0.92, 1.0), "intensity": 3.0, "roll": 0.1, "big": true, "life": 9.0})
		"stance":
			for k in 10:
				fx.emit("smoke", Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 1.6), randf_range(-0.6, 0.6)), Vector3(0, 0.2, 0), 30.0, 0.8, Color(0.8, 0.8, 0.85, 0.4))
		"xcut":
			var n := fx.projectile_visual("xslash", {"color": Color(0.9, 0.92, 1.0), "scale": 1.2})
			holder.add_child(n)
			n.global_position = Vector3(0.1, 1.2, 1.2)
			n.look_at(n.global_position + Vector3(0, 0, 1), Vector3.UP)
		"yuto_ult":
			for k in 8:
				fx.slash(Vector3(randf_range(-0.5, 0.5), 1.1 + randf_range(-0.3, 0.4), 0.5), randf() * TAU, {"color": Color(1, 0.25, 0.3) if k % 3 == 0 else Color(0.95, 0.95, 1.0), "intensity": 3.0, "roll": randf_range(-1.5, 1.5), "life": 9.0})
		"potion":
			var bottle: Node3D = load("res://assets/dungeon/bottle_A_labeled_brown.gltf").instantiate()
			holder.add_child(bottle)
			Toon.convert_tree(bottle, true, 0.5)
			var hb := 0.1
			for mi in bottle.find_children("*", "MeshInstance3D", true, false):
				hb = maxf(hb, (mi as MeshInstance3D).get_aabb().end.y)
			bottle.scale = Vector3.ONE * (0.5 / hb)
			var gb := fx.glow_ball(Color(1.4, 0.2, 0.35), 0.06)
			holder.add_child(gb)
			gb.position = Vector3(0, 0.18, 0)
			fx.burst("heal", Vector3(0, 0.1, 0), {"n": 14})
			fx.burst("star", Vector3(0, 0.4, 0.1), {"n": 5, "color": Color(1, 0.5, 0.6)})

## Cópia fantasma da pose atual deslocada (para mostrar movimento no ícone).
func _ghost_copy(rig: CharRig, off: Vector3, col: Color) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ghost.gdshader")
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("alpha", 0.75)
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var src: MeshInstance3D = mi
		if src.mesh == null or not src.is_visible_in_tree():
			continue
		var mesh: Mesh = src.bake_mesh_from_current_skeleton_pose() if src.skin else src.mesh
		var g := MeshInstance3D.new()
		g.mesh = mesh
		g.material_override = mat
		holder.add_child(g)
		g.global_transform = src.global_transform
		g.global_position += off
