class_name CharFactory
## Monta os personagens a partir dos trajes modulares + animações retargetadas +
## cabeças/cabelos procedurais + capas simuladas + armas KayKit.

const CH := "res://assets/characters/"
const TOON := preload("res://shaders/toon_char.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const HEAD := preload("res://shaders/head.gdshader")
const HAIR := preload("res://shaders/hair.gdshader")
const CLOTH := preload("res://shaders/cloth.gdshader")

static var _scenes := {}
static var _libs := {}
static var _mann := {}
static var _hair_cache := {}

static func scene(p: String) -> PackedScene:
	if not _scenes.has(p):
		_scenes[p] = load(p)
	return _scenes[p]

static func lib(n: String) -> AnimationLibrary:
	if not _libs.has(n):
		_libs[n] = load("res://assets/anims/lib_%s.res" % n)
	return _libs[n]

# ---------------------------------------------------------------------
#  Cabelos (camadas: estilo + cor)
# ---------------------------------------------------------------------
const PI2 := PI

static func hair_style(name: String) -> Dictionary:
	match name:
		"kiana":
			return {"seed": 11, "hairline": 0.7, "cap_bottom": 1.85, "strands": [
				{"count": 20, "th": [0.3, 0.9], "ph": [-0.95, 0.95], "dir": Vector3(0, -0.6, 0.9), "out": 0.55, "len": [0.05, 0.1], "w": [0.016, 0.026], "gravity": 0.3, "jitter": 0.3, "curl": 0.12},
				{"count": 26, "th": [0.65, 1.55], "ph": [0.9, 2.2], "mirror": true, "dir": Vector3(0, -1, -0.1), "out": 0.75, "len": [0.12, 0.21], "w": [0.018, 0.03], "gravity": 0.28, "jitter": 0.4, "curl": 0.15},
				{"count": 24, "th": [0.5, 1.8], "ph": [2.2, 4.1], "dir": Vector3(0, -1, -0.35), "out": 0.7, "len": [0.14, 0.24], "w": [0.02, 0.032], "gravity": 0.3, "jitter": 0.35, "curl": 0.15},
				{"count": 18, "th": [0.05, 0.6], "ph": [-3.1, 3.1], "dir": Vector3(0, 0.4, -0.2), "out": 1.0, "len": [0.06, 0.12], "w": [0.016, 0.026], "gravity": 0.38, "jitter": 0.55, "curl": 0.2}]}
		"near":
			return {"seed": 5, "hairline": 0.75, "cap_bottom": 1.6, "strands": [
				{"count": 10, "th": [0.4, 0.9], "ph": [-0.9, 0.9], "dir": Vector3(0, -1, 0.5), "out": 0.3, "len": [0.08, 0.13], "w": [0.014, 0.022], "gravity": 0.3, "jitter": 0.35},
				{"count": 8, "th": [0.8, 1.3], "ph": [1.0, 1.6], "mirror": true, "dir": Vector3(0, -1, 0.2), "out": 0.5, "len": [0.12, 0.18], "w": [0.014, 0.02], "gravity": 0.35, "jitter": 0.3}]}
		"calista":
			return {"seed": 9, "hairline": 0.75, "cap_bottom": 1.7, "colliders": [[Vector3(0.17, -0.26, -0.02), 0.11], [Vector3(-0.17, -0.26, -0.02), 0.11], [Vector3(0, -0.3, 0.02), 0.13]], "strands": [
				{"count": 10, "th": [0.4, 0.95], "ph": [-0.9, 0.9], "dir": Vector3(0, -1, 0.45), "out": 0.3, "len": [0.1, 0.16], "w": [0.018, 0.026], "gravity": 0.3, "curl": 0.25, "jitter": 0.3},
				{"count": 16, "th": [0.8, 1.4], "ph": [0.9, 1.8], "mirror": true, "dir": Vector3(0, -1, 0.35), "out": 0.5, "len": [0.3, 0.46], "w": [0.022, 0.034], "gravity": 0.5, "curl": 0.4, "jitter": 0.25, "segs": 10},
				{"count": 10, "th": [0.9, 1.6], "ph": [1.8, 2.6], "mirror": true, "dir": Vector3(0, -1, -0.2), "out": 0.5, "len": [0.3, 0.42], "w": [0.022, 0.034], "gravity": 0.5, "curl": 0.4, "segs": 10}]}
		"amnon":
			return {"seed": 21, "hairline": 0.8, "cap_bottom": 1.85, "colliders": [[Vector3(0.18, -0.27, -0.03), 0.11], [Vector3(-0.18, -0.27, -0.03), 0.11], [Vector3(0, -0.28, -0.08), 0.13]], "strands": [
				{"count": 14, "th": [0.4, 1.0], "ph": [-1.0, 1.0], "dir": Vector3(0, -1, 0.4), "out": 0.5, "len": [0.09, 0.16], "w": [0.018, 0.028], "gravity": 0.3, "jitter": 0.5, "curl": 0.2},
				{"count": 22, "th": [0.7, 1.6], "ph": [1.0, 2.3], "mirror": true, "dir": Vector3(0, -1, -0.2), "out": 0.8, "len": [0.16, 0.3], "w": [0.02, 0.032], "gravity": 0.4, "jitter": 0.5, "curl": 0.3, "segs": 9},
				{"count": 22, "th": [0.5, 1.9], "ph": [2.3, 4.0], "dir": Vector3(0, -1, -0.3), "out": 0.7, "len": [0.24, 0.4], "w": [0.022, 0.034], "gravity": 0.45, "jitter": 0.45, "curl": 0.3, "segs": 10},
				{"count": 12, "th": [0.05, 0.6], "ph": [-3.1, 3.1], "dir": Vector3(0, 0.3, -0.3), "out": 1.0, "len": [0.06, 0.12], "w": [0.018, 0.026], "gravity": 0.35, "jitter": 0.6}]}
		"amnon_lock":
			return {"seed": 4, "cap": false, "strands": [
				{"count": 9, "th": [0.15, 0.55], "ph": [-0.45, 0.05], "dir": Vector3(0.2, -1, 0.7), "out": 0.4, "len": [0.12, 0.2], "w": [0.02, 0.03], "gravity": 0.3, "jitter": 0.3, "curl": 0.15}]}
		"darin":
			return {"seed": 33, "hairline": 0.8, "cap_bottom": 1.7, "strands": [
				{"count": 16, "th": [0.3, 0.95], "ph": [-1.0, 1.0], "dir": Vector3(0, -1, 0.55), "out": 0.45, "len": [0.08, 0.14], "w": [0.018, 0.028], "gravity": 0.28, "jitter": 0.5, "curl": 0.2},
				{"count": 22, "th": [0.6, 1.5], "ph": [1.0, 2.3], "mirror": true, "dir": Vector3(0, -1, -0.1), "out": 0.9, "len": [0.08, 0.15], "w": [0.018, 0.028], "gravity": 0.25, "jitter": 0.55},
				{"count": 22, "th": [0.4, 1.7], "ph": [2.3, 4.0], "dir": Vector3(0, -0.6, -0.5), "out": 0.9, "len": [0.09, 0.16], "w": [0.02, 0.03], "gravity": 0.25, "jitter": 0.55},
				{"count": 18, "th": [0.0, 0.6], "ph": [-3.1, 3.1], "dir": Vector3(0, 0.5, 0), "out": 1.0, "len": [0.07, 0.13], "w": [0.018, 0.028], "gravity": 0.22, "jitter": 0.6}]}
		"viktor":
			return {"seed": 41, "hairline": 0.7, "cap_bottom": 1.8, "ponytail": {"pos": Vector3(0, -0.02, -0.105), "len": 0.42, "w": 0.024, "count": 9}, "strands": [
				{"count": 14, "th": [0.3, 0.95], "ph": [-0.2, 1.0], "dir": Vector3(-0.2, -1, 0.5), "out": 0.35, "len": [0.12, 0.2], "w": [0.018, 0.028], "gravity": 0.3, "jitter": 0.3, "curl": 0.1},
				{"count": 8, "th": [0.4, 0.9], "ph": [-1.0, -0.2], "dir": Vector3(0, -1, 0.4), "out": 0.35, "len": [0.08, 0.13], "w": [0.016, 0.024], "gravity": 0.3, "jitter": 0.35},
				{"count": 20, "th": [0.65, 1.5], "ph": [1.0, 2.3], "mirror": true, "dir": Vector3(0, -1, -0.1), "out": 0.8, "len": [0.1, 0.17], "w": [0.018, 0.028], "gravity": 0.3, "jitter": 0.45},
				{"count": 14, "th": [0.05, 0.6], "ph": [-3.1, 3.1], "dir": Vector3(0, 0.4, -0.2), "out": 1.0, "len": [0.06, 0.11], "w": [0.016, 0.024], "gravity": 0.35, "jitter": 0.55}]}
		"krauser":
			return {"seed": 51, "hairline": 0.75, "cap_bottom": 1.75, "colliders": [[Vector3(0.19, -0.28, -0.03), 0.12], [Vector3(-0.19, -0.28, -0.03), 0.12], [Vector3(0, -0.3, -0.1), 0.15]], "strands": [
				{"count": 12, "th": [0.25, 0.75], "ph": [0.15, 1.2], "mirror": true, "dir": Vector3(0, -1, 0.3), "out": 0.3, "len": [0.32, 0.45], "w": [0.02, 0.03], "gravity": 0.7, "jitter": 0.12, "segs": 10},
				{"count": 22, "th": [0.6, 1.6], "ph": [1.2, 2.3], "mirror": true, "dir": Vector3(0, -1, -0.15), "out": 0.5, "len": [0.4, 0.55], "w": [0.022, 0.032], "gravity": 0.75, "jitter": 0.12, "segs": 11},
				{"count": 24, "th": [0.4, 1.9], "ph": [2.3, 4.0], "dir": Vector3(0, -1, -0.3), "out": 0.5, "len": [0.45, 0.62], "w": [0.024, 0.034], "gravity": 0.75, "jitter": 0.12, "segs": 11}]}
		"yuto":
			return {"seed": 61, "hairline": 0.72, "cap_bottom": 1.75, "ponytail": {"pos": Vector3(0.075, 0.07, -0.07), "len": 0.36, "w": 0.026, "count": 10}, "strands": [
				{"count": 16, "th": [0.3, 0.95], "ph": [-1.0, 1.0], "dir": Vector3(0, -1, 0.55), "out": 0.4, "len": [0.1, 0.17], "w": [0.018, 0.028], "gravity": 0.28, "jitter": 0.55, "curl": 0.15},
				{"count": 20, "th": [0.65, 1.5], "ph": [1.0, 2.3], "mirror": true, "dir": Vector3(0, -1, -0.1), "out": 0.8, "len": [0.09, 0.16], "w": [0.018, 0.028], "gravity": 0.28, "jitter": 0.5},
				{"count": 16, "th": [0.05, 0.6], "ph": [-3.1, 3.1], "dir": Vector3(0, 0.45, -0.2), "out": 1.0, "len": [0.06, 0.12], "w": [0.016, 0.024], "gravity": 0.3, "jitter": 0.6}]}
		"yuto_streak":
			return {"seed": 62, "cap": false, "strands": [
				{"count": 5, "th": [0.3, 0.8], "ph": [0.3, 0.9], "dir": Vector3(0.2, -1, 0.6), "out": 0.42, "len": [0.12, 0.18], "w": [0.016, 0.022], "gravity": 0.28, "jitter": 0.3},
				{"count": 4, "th": [0.4, 0.9], "ph": [-1.0, -0.5], "dir": Vector3(-0.2, -1, 0.6), "out": 0.42, "len": [0.1, 0.16], "w": [0.016, 0.022], "gravity": 0.28, "jitter": 0.3}]}
		"yuto_streak2":
			return {"seed": 63, "cap": false, "strands": [
				{"count": 5, "th": [0.35, 0.85], "ph": [-0.4, 0.2], "dir": Vector3(0, -1, 0.6), "out": 0.43, "len": [0.12, 0.18], "w": [0.016, 0.022], "gravity": 0.28, "jitter": 0.3},
				{"count": 5, "th": [0.7, 1.3], "ph": [1.2, 1.8], "mirror": true, "dir": Vector3(0, -1, -0.1), "out": 0.82, "len": [0.1, 0.15], "w": [0.016, 0.022], "gravity": 0.28, "jitter": 0.3}]}
		"darius":
			return {"seed": 2, "cap": false, "ponytail": {"pos": Vector3(0, 0.1, -0.06), "len": 0.22, "w": 0.026, "count": 6}, "strands": []}
		"mira":
			return {"seed": 8, "hairline": 0.85, "cap_bottom": 1.7, "ponytail": {"pos": Vector3(0, 0.07, -0.1), "len": 0.07, "w": 0.04, "count": 10}, "strands": [
				{"count": 10, "th": [0.6, 1.3], "ph": [1.0, 2.0], "mirror": true, "dir": Vector3(0, -1, -0.2), "out": 0.6, "len": [0.05, 0.09], "w": [0.016, 0.022], "gravity": 0.3, "jitter": 0.4}]}
		"rurik":
			return {"seed": 13, "hairline": 0.95, "cap_bottom": 1.75, "strands": [
				{"count": 18, "th": [0.6, 1.6], "ph": [1.2, 4.5], "dir": Vector3(0, -1, -0.2), "out": 0.7, "len": [0.06, 0.11], "w": [0.018, 0.026], "gravity": 0.3, "jitter": 0.4}]}
		"rurik_beard", "thug_beard":
			return {"seed": 17, "cap": false, "strands": [
				{"count": 26, "th": [2.0, 2.75], "ph": [-1.4, 1.4], "dir": Vector3(0, -1, 0.35), "out": 0.55, "len": [0.06, 0.14] if name == "rurik_beard" else [0.03, 0.06], "w": [0.018, 0.028], "gravity": 0.35, "jitter": 0.3}]}
		"short":
			return {"seed": 19, "hairline": 0.9, "cap_bottom": 1.6, "strands": [
				{"count": 18, "th": [0.1, 1.3], "ph": [-3.1, 3.1], "dir": Vector3(0, 0.1, 0), "out": 1.0, "len": [0.03, 0.06], "w": [0.016, 0.024], "gravity": 0.3, "jitter": 0.5}]}
		"woman":
			return {"seed": 23, "hairline": 0.8, "cap_bottom": 1.75, "ponytail": {"pos": Vector3(0, 0.02, -0.11), "len": 0.3, "w": 0.024, "count": 8}, "strands": [
				{"count": 10, "th": [0.4, 0.95], "ph": [-0.9, 0.9], "dir": Vector3(0, -1, 0.4), "out": 0.3, "len": [0.08, 0.12], "w": [0.016, 0.024], "gravity": 0.3, "jitter": 0.3}]}
	return {"seed": 1, "strands": []}

# ---------------------------------------------------------------------
#  Fichas
# ---------------------------------------------------------------------
static func spec(id: String, o: Dictionary) -> Dictionary:
	var dark_tunic := {"saturation": 0.2}
	match id:
		"kiana":
			return {"base": CH + "Female_Peasant.gltf", "lib": "female", "scale": 0.95, "skin": Color(0.43, 0.57, 0.26),
				"mesh": {
					"Female_Peasant_Body": {"saturation": 0.15, "tint": Vector3(0.42, 0.52, 1.15), "brightness": 1.1},
					"Female_Peasant_Legs": {"saturation": 0.05, "tint": Vector3(0.32, 0.3, 0.34)},
					"Female_Peasant_Arms": {"saturation": 0.1, "tint": Vector3(0.3, 0.3, 0.36)},
					"Female_Peasant_Feet": {"saturation": 0.9, "tint": Vector3(0.95, 0.75, 0.6)}},
				"head": {"face": "kiana", "skin": Color(0.43, 0.57, 0.26), "eye_glow": Color(1.4, 0.1, 0.05), "r": Vector3(0.086, 0.108, 0.096), "blush": 0.05, "blush_col": Color(0.3, 0.45, 0.15)},
				"hair": [["kiana", Color(0.8, 0.82, 0.86), Color(0.88, 0.89, 0.93), 0.5]],
				"ears": {"len": 0.085, "tilt": 0.55},
				"cloaks": [{"w": 0.42, "len": 1.08, "col": Color(0.05, 0.045, 0.06), "inner": Color(0.03, 0.03, 0.04), "tatter": 0.22}],
				"fur_cuffs": Color(0.92, 0.9, 0.85),
				"belt_pouch": true,
				"weapon": "kael_dagger", "ukulele": true}
		"near":
			return {"base": CH + "Male_Ranger.gltf", "lib": "male", "scale": 0.97, "skin": Color(0.93, 0.8, 0.68),
				"tex": {"MI_Ranger": CH + "T_Ranger_3_BaseColor.png"},
				"mat": {"MI_Ranger": {"saturation": 0.35, "tint": Vector3(0.42, 0.4, 0.46), "light_swap": 1.0, "light_swap_col": Color(0.12, 0.11, 0.14)}},
				"head": {"face": "near", "skin": Color(0.93, 0.8, 0.68), "r": Vector3(0.084, 0.106, 0.094), "hood_fit": true},
				"hair": [["near", Color(0.74, 0.75, 0.8), Color(0.82, 0.82, 0.86), 0.4]],
				"ears": {"len": 0.07, "tilt": 0.5}, "mask": Color(0.06, 0.06, 0.08),
				"sash": Color(0.36, 0.16, 0.5),
				"skirts": [{"front": true, "col": Color(0.06, 0.055, 0.07), "len": 0.82, "w": 0.34}, {"front": false, "col": Color(0.06, 0.055, 0.07), "len": 0.85, "w": 0.36}],
				"weapon": "dagger_A", "weapon_l": "dagger_A"}
		"calista":
			return {"base": CH + "Female_Ranger.gltf", "lib": "female", "scale": 0.97, "skin": Color(0.96, 0.82, 0.72),
				"tex": {"MI_Ranger": CH + "T_Ranger_3_BaseColor.png"},
				"mat": {"MI_Ranger": {"saturation": 0.4, "tint": Vector3(0.45, 0.42, 0.42), "light_swap": 1.0, "light_swap_col": Color(0.16, 0.13, 0.12)}},
				"head": {"face": "calista", "skin": Color(0.96, 0.82, 0.72), "r": Vector3(0.084, 0.106, 0.094), "hood_fit": true, "blush": 0.2},
				"hair": [["calista", Color(0.85, 0.32, 0.08), Color(0.98, 0.52, 0.18), 0.45]],
				"cloaks": [{"w": 0.44, "len": 1.12, "col": Color(0.04, 0.035, 0.04), "inner": Color(0.03, 0.02, 0.02), "tatter": 0.2}],
				"weapon_l": "bow"}
		"amnon":
			return {"base": CH + "Male_Peasant.gltf", "lib": "male", "scale": 1.0, "skin": Color(0.62, 0.12, 0.13),
				"mesh": {
					"Male_Peasant_Body": {"swap1": Vector4(0.08, 0.09, 0.25, 1.0), "swap1_col": Color(0.2, 0.28, 0.55), "light_swap": 1.0, "light_swap_col": Color(0.95, 0.93, 0.9)},
					"Male_Peasant_Arms": {"light_swap": 1.0, "light_swap_col": Color(0.95, 0.93, 0.9), "swap1": Vector4(0.08, 0.1, 0.25, 1.0), "swap1_col": Color(0.92, 0.9, 0.87)},
					"Male_Peasant_Legs": {"saturation": 0.1, "tint": Vector3(0.38, 0.4, 0.44)},
					"Male_Peasant_Feet": {"saturation": 0.6, "tint": Vector3(0.75, 0.62, 0.45)}},
				"head": {"face": "amnon", "skin": Color(0.62, 0.12, 0.13), "r": Vector3(0.088, 0.11, 0.098), "blush": 0.0},
				"hair": [["amnon", Color(0.05, 0.04, 0.05), Color(0.1, 0.08, 0.1), 0.3], ["amnon_lock", Color(0.84, 0.84, 0.86), Color(0.9, 0.9, 0.92), 0.5]],
				"ears": {"len": 0.08, "tilt": 0.45}, "horns": "ram", "horn_col": Color(0.13, 0.12, 0.2),
				"belt_pouch": true, "weapon_l": "bow"}
		"darin":
			return {"base": CH + "Male_Ranger.gltf", "lib": "male", "scale": 1.0, "skin": Color(0.88, 0.68, 0.5),
				"remove": ["Male_Ranger_Body", "Male_Ranger_Arms", "Male_Ranger_Head_Hood", "Male_Ranger_Acc_Pauldron", "Male_Ranger_Arms_Bracer"],
				"mannequin": ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r", "Head", "neck_01"],
				"mat": {"MI_Ranger": {"saturation": 0.3, "tint": Vector3(0.5, 0.45, 0.4)}},
				"head": {"face": "darin", "skin": Color(0.88, 0.68, 0.5), "r": Vector3(0.088, 0.11, 0.098)},
				"hair": [["darin", Color(0.26, 0.15, 0.08), Color(0.36, 0.22, 0.12), 0.35]],
				"antlers": true, "flower": true,
				"skirts": [{"front": true, "col": Color(0.2, 0.3, 0.14), "len": 0.6, "w": 0.36}, {"front": false, "col": Color(0.2, 0.3, 0.14), "len": 0.7, "w": 0.38}],
				"wristbands": Color(0.12, 0.1, 0.08)}
		"viktor":
			return {"base": CH + "Male_Peasant.gltf", "lib": "male", "scale": 1.03, "skin": Color(0.96, 0.85, 0.76),
				"remove": ["Male_Peasant_Body", "Male_Peasant_Arms"],
				"mannequin": ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r", "Head", "neck_01"],
				"mesh": {"Male_Peasant_Legs": {"saturation": 0.1, "tint": Vector3(0.3, 0.38, 0.62)}, "Male_Peasant_Feet": {"saturation": 0.2, "tint": Vector3(1.0, 0.92, 0.78), "brightness": 1.3}},
				"head": {"face": "viktor", "skin": Color(0.96, 0.85, 0.76), "r": Vector3(0.086, 0.108, 0.096)},
				"hair": [["viktor", Color(0.72, 0.74, 0.8), Color(0.82, 0.83, 0.88), 0.5]],
				"ears": {"len": 0.06, "tilt": 0.45},
				"wrap": Color(0.92, 0.9, 0.85), "sash": Color(0.6, 0.12, 0.1),
				"cloaks": [{"w": 0.56, "len": 1.08, "col": Color(0.82, 0.82, 0.84), "inner": Color(0.12, 0.16, 0.3), "tatter": 0.12, "fur": true, "collar": true, "collar_col": Color(0.12, 0.17, 0.32)}],
				"tail": Color(0.8, 0.8, 0.84), "gloves": Color(0.1, 0.12, 0.18)}
		"krauser":
			return {"base": CH + "Male_Ranger.gltf", "lib": "male", "scale": 1.08, "skin": Color(0.9, 0.74, 0.62),
				"remove": ["Male_Ranger_Head_Hood"],
				"tex": {"MI_Ranger": CH + "T_Ranger_3_BaseColor.png"},
				"mat": {"MI_Ranger": {"saturation": 0.6, "tint": Vector3(0.7, 0.55, 0.62), "light_swap": 1.0, "light_swap_col": Color(0.55, 0.45, 0.5)}},
				"head": {"face": "krauser", "skin": Color(0.9, 0.74, 0.62), "r": Vector3(0.088, 0.112, 0.098), "eye_glow": Color(1.2, 0.8, 0.1), "blush": 0.0},
				"hair": [["krauser", Color(0.08, 0.06, 0.05), Color(0.16, 0.12, 0.09), 0.3]],
				"horns": "dragon", "horn_col": Color(0.25, 0.2, 0.15),
				"cloaks": [{"w": 0.5, "len": 1.15, "col": Color(0.2, 0.13, 0.3), "inner": Color(0.1, 0.06, 0.14), "tatter": 0.25}],
				"tail": Color(0.2, 0.25, 0.2), "dragon_tail": true, "spikes": true, "crystal": true, "back_sword": true}
		"yuto":
			return {"base": CH + "Male_Ranger.gltf", "lib": "male", "scale": 1.0, "skin": Color(0.93, 0.8, 0.68),
				"remove": ["Male_Ranger_Head_Hood", "Male_Ranger_Acc_Pauldron"],
				"mat": {"MI_Ranger": {"saturation": 0.55, "tint": Vector3(0.78, 0.4, 0.26)}},
				"head": {"face": "yuto", "skin": Color(0.93, 0.8, 0.68), "r": Vector3(0.086, 0.108, 0.096), "blush": 0.0},
				"hair": [["yuto", Color(0.04, 0.04, 0.06), Color(0.07, 0.07, 0.1), 0.3], ["yuto_streak", Color(0.6, 0.08, 0.08), Color(0.75, 0.15, 0.1), 0.3], ["yuto_streak2", Color(0.1, 0.22, 0.6), Color(0.15, 0.32, 0.75), 0.3]],
				"twig": true,
				"cloaks": [{"w": 0.52, "len": 1.0, "col": Color(0.72, 0.32, 0.18), "inner": Color(0.08, 0.05, 0.05), "tatter": 0.04, "waves": true}],
				"scarf": Color(0.52, 0.08, 0.07), "sash": Color(0.08, 0.08, 0.1),
				"weapon": "katana", "katana_hip": true}
		"darius":
			return {"base": CH + "Male_Peasant.gltf", "lib": "male", "scale": 1.24, "skin": Color(0.38, 0.47, 0.28),
				"remove": ["Male_Peasant_Body", "Male_Peasant_Arms"],
				"mannequin": ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r", "Head", "neck_01"],
				"mesh": {"Male_Peasant_Legs": {"saturation": 0.4, "tint": Vector3(0.55, 0.42, 0.32)}},
				"bone_scale": {"spine_02": Vector3(1.15, 1.0, 1.12), "spine_03": Vector3(1.12, 1.0, 1.12), "upperarm_l": Vector3(1.0, 1.15, 1.0), "upperarm_r": Vector3(1.0, 1.15, 1.0)},
				"head": {"face": "darius", "angry": true, "skin": Color(0.38, 0.47, 0.28), "r": Vector3(0.096, 0.108, 0.1), "blush": 0.0},
				"hair": [["darius", Color(0.05, 0.05, 0.05), Color(0.1, 0.1, 0.1), 0.2]],
				"ears": {"len": 0.06, "tilt": 0.3}, "tusks": true, "tattoo": true,
				"pauldron": true, "harness": Color(0.25, 0.16, 0.1), "weapon": "cleaver"}
		"thug":
			var r: int = o.get("seed", 0)
			var cols := [Vector3(0.7, 0.55, 0.45), Vector3(0.5, 0.45, 0.42), Vector3(0.62, 0.5, 0.4), Vector3(0.45, 0.4, 0.38), Vector3(0.6, 0.42, 0.36)]
			var skins := [Color(0.88, 0.7, 0.58), Color(0.78, 0.6, 0.46), Color(0.66, 0.48, 0.34), Color(0.92, 0.78, 0.66), Color(0.55, 0.38, 0.26)]
			var ranger := r % 2 == 0
			var w: String = o.get("weapon", ["sword_A", "axe_A", "hammer_A", "sword_B"][r % 4])
			return {"base": CH + ("Male_Ranger.gltf" if ranger else "Male_Peasant.gltf"), "lib": "male", "scale": 0.98 + (r % 5) * 0.025, "skin": skins[r % 5],
				"remove": ([] if r % 3 == 0 else ["Male_Ranger_Head_Hood"]) + (["Male_Ranger_Acc_Pauldron"] if r % 4 == 1 else []),
				"tex": {"MI_Ranger": CH + "T_Ranger_3_BaseColor.png", "MI_Peasant": CH + ("T_Peasant_2_BaseColor.png" if r % 2 else "T_Peasant_BaseColor.png")},
				"mat": {"MI_Ranger": {"saturation": 0.5, "tint": cols[r % 5]}, "MI_Peasant": {"saturation": 0.6, "tint": cols[(r + 2) % 5] * 1.1}},
				"head": {"face": "thug", "angry": true, "skin": skins[r % 5], "r": Vector3(0.088, 0.108, 0.098), "hood_fit": r % 3 == 0, "blush": 0.0},
				"hair": [] if r % 3 == 0 else [["short", [Color(0.18, 0.12, 0.08), Color(0.08, 0.07, 0.06), Color(0.35, 0.24, 0.12)][r % 3], Color(0.2, 0.15, 0.1), 0.2]] + ([["thug_beard", Color(0.2, 0.14, 0.09), Color(0.25, 0.18, 0.12), 0.1]] if r % 4 == 2 else []),
				"weapon": w}
		"shadow":
			return {"base": CH + "Male_Ranger.gltf", "lib": "male", "scale": o.get("scale", 1.05), "skin": Color(0.02, 0.01, 0.03),
				"remove": ["Male_Ranger_Head_Hood", "Male_Ranger_Body_Belt_1", "Male_Ranger_Body_Belt_2"],
				"mat": {"MI_Ranger": {"saturation": 0.0, "tint": Vector3(0.02, 0.015, 0.03), "rim_strength": 1.6, "rim_col": Color(0.5, 0.1, 0.4)}},
				"head": {"face": "", "skin": Color(0.02, 0.01, 0.03), "r": Vector3(0.09, 0.115, 0.1), "blush": 0.0},
				"hair": [], "shadow": true}
		"mira":
			return {"base": CH + "Female_Peasant.gltf", "lib": "female", "scale": 0.84, "skin": Color(0.86, 0.7, 0.6),
				"tex": {"MI_Peasant": CH + "T_Peasant_2_BaseColor.png"},
				"mat": {"MI_Peasant": {"saturation": 0.3, "tint": Vector3(0.62, 0.5, 0.72)}},
				"head": {"face": "mira", "skin": Color(0.86, 0.7, 0.6), "r": Vector3(0.084, 0.102, 0.094), "blush": 0.1},
				"hair": [["mira", Color(0.72, 0.72, 0.76), Color(0.8, 0.8, 0.84), 0.2]],
				"hunch": true, "cane": true,
				"cloaks": [{"w": 0.4, "len": 0.5, "col": Color(0.4, 0.14, 0.2), "inner": Color(0.25, 0.08, 0.12), "tatter": 0.05}]}
		"rurik":
			return {"base": CH + "Male_Peasant.gltf", "lib": "male", "scale": 1.14, "skin": Color(0.86, 0.66, 0.54),
				"mat": {"MI_Peasant": {"saturation": 0.7, "tint": Vector3(0.75, 0.62, 0.5)}},
				"bone_scale": {"spine_02": Vector3(1.15, 1, 1.15), "spine_03": Vector3(1.18, 1, 1.15), "upperarm_l": Vector3(1.15, 1, 1.15), "upperarm_r": Vector3(1.15, 1, 1.15)},
				"head": {"face": "rurik", "skin": Color(0.86, 0.66, 0.54), "r": Vector3(0.094, 0.11, 0.1), "blush": 0.08},
				"hair": [["rurik", Color(0.55, 0.52, 0.47), Color(0.65, 0.62, 0.58), 0.2], ["rurik_beard", Color(0.5, 0.47, 0.42), Color(0.62, 0.6, 0.56), 0.15]],
				"apron": Color(0.65, 0.58, 0.46)}
		"townsfolk":
			var r: int = o.get("seed", 0)
			var fem := r % 2 == 1
			var tints := [Vector3(0.6, 0.5, 0.75), Vector3(0.75, 0.55, 0.45), Vector3(0.45, 0.62, 0.5), Vector3(0.8, 0.72, 0.5), Vector3(0.55, 0.55, 0.7)]
			var skins := [Color(0.9, 0.74, 0.62), Color(0.78, 0.6, 0.46), Color(0.94, 0.8, 0.7), Color(0.6, 0.44, 0.3)]
			return {"base": CH + ("Female_Peasant.gltf" if fem else "Male_Peasant.gltf"), "lib": "female" if fem else "male", "scale": 0.93 + (r % 4) * 0.03, "skin": skins[r % 4],
				"tex": {"MI_Peasant": CH + ("T_Peasant_2_BaseColor.png" if r % 3 == 0 else "T_Peasant_BaseColor.png")},
				"mat": {"MI_Peasant": {"saturation": 0.6, "tint": tints[r % 5]}},
				"head": {"face": "woman" if fem else "man", "skin": skins[r % 4], "r": Vector3(0.086, 0.106, 0.095), "blush": 0.12 if fem else 0.0},
				"hair": [["woman" if fem else "short", [Color(0.25, 0.15, 0.08), Color(0.5, 0.35, 0.15), Color(0.08, 0.06, 0.05)][r % 3], Color(0.35, 0.25, 0.15), 0.25]]}
		"elemental":
			return {"base": "res://assets/anims/UAL1_Standard.glb", "lib": "mannequin", "scale": 2.3, "skin": Color(0.2, 0.5, 0.9),
				"elemental": true, "head": {}, "hair": []}
	return {"base": CH + "Male_Peasant.gltf", "lib": "male", "head": {"face": "man"}, "hair": []}

# ---------------------------------------------------------------------
#  Construção
# ---------------------------------------------------------------------
static func build(id: String, o := {}) -> CharRig:
	var sp := spec(id, o)
	for k in o:
		if k != "seed" and k != "weapon" and k != "scale":
			sp[k] = o[k]
	var rig := CharRig.new()
	rig.id = id
	rig.spec = sp
	rig.name = "Rig_" + id
	var model: Node3D = scene(sp.base).instantiate()
	rig.model = model
	rig.add_child(model)
	model.scale = Vector3.ONE * sp.get("scale", 1.0)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	rig.skel = skel
	var old_ap := model.find_child("AnimationPlayer", true, false)
	if old_ap:
		old_ap.get_parent().remove_child(old_ap)
		old_ap.free()
	for n in sp.get("remove", []):
		var m := skel.get_node_or_null(n)
		if m:
			skel.remove_child(m); m.free()
	if sp.has("mannequin"):
		_add_mannequin(skel, sp.mannequin)
	# materiais
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE
	outline_mat.set_shader_parameter("width", 0.0045 if not sp.get("shadow", false) else 0.0)
	if sp.get("shadow", false):
		outline_mat.set_shader_parameter("color", Color(0.25, 0.05, 0.25))
		outline_mat.set_shader_parameter("width", 0.006)
	for mi in skel.get_children():
		if not (mi is MeshInstance3D):
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(si)
			var mname: String = src.resource_name if src else ""
			var m := ShaderMaterial.new()
			m.shader = TOON
			if src is BaseMaterial3D:
				var tex = src.albedo_texture
				if sp.get("tex", {}).has(mname):
					tex = load(sp.tex[mname])
				m.set_shader_parameter("albedo_tex", tex)
			var is_skin: bool = mname.contains("Regular") or mi.name == "Mannequin" or sp.get("elemental", false)
			if is_skin:
				m.set_shader_parameter("skin_mode", true)
				m.set_shader_parameter("skin_col", sp.get("skin", Color(0.9, 0.7, 0.6)))
				m.set_shader_parameter("roughness_v", 0.65)
				if sp.get("tattoo", false) and mi.name == "Mannequin":
					m.set_shader_parameter("albedo_tex", _tattoo_tex())
			for k in sp.get("mat", {}).get(mname, {}):
				m.set_shader_parameter(k, sp.mat[mname][k])
			if not is_skin:
				for k in sp.get("mesh", {}).get(str(mi.name), {}):
					m.set_shader_parameter(k, sp.mesh[str(mi.name)][k])
			m.next_pass = outline_mat
			mi.set_surface_override_material(si, m)
			rig.mats.append(m)
	# animação
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", lib(sp.get("lib", "male")))
	ap.playback_default_blend_time = 0.15
	rig.anim = ap
	for b in sp.get("bone_scale", {}):
		var bi := skel.find_bone(b)
		if bi >= 0:
			skel.set_bone_pose_scale(bi, sp.bone_scale[b])
	var po := PoseOverride.new()
	skel.add_child(po)
	rig.pose = po
	if not sp.get("elemental", false):
		_build_head(rig, sp)
		_build_extras(rig, sp)
	var hb := skel.find_bone("Head")
	rig.height = (skel.get_bone_global_rest(hb).origin.y + 0.24) * sp.get("scale", 1.0)
	ap.play("Idle")
	return rig

## Malha do manequim (UAL) religada ao esqueleto do traje, sem as partes cobertas.
static func _add_mannequin(skel: Skeleton3D, drop: Array) -> void:
	var key := ",".join(drop)
	if not _mann.has(key):
		var src: Node = scene("res://assets/anims/UAL1_Standard.glb").instantiate()
		var mi: MeshInstance3D = src.find_child("Mannequin", true, false)
		var mesh: ArrayMesh = mi.mesh
		var skin: Skin = mi.skin
		var drop_idx := {}
		for i in skin.get_bind_count():
			if skin.get_bind_name(i) in drop:
				drop_idx[i] = true
		var out := ArrayMesh.new()
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var per: int = bones.size() / arr[Mesh.ARRAY_VERTEX].size()
			var keep := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var bad := false
				for k in 3:
					var v := idx[t + k]
					var best := 0
					for q in per:
						if weights[v * per + q] > weights[v * per + best]:
							best = q
					if drop_idx.has(bones[v * per + best]):
						bad = true
				if not bad:
					keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
			arr[Mesh.ARRAY_INDEX] = keep
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
			out.surface_set_material(s, mesh.surface_get_material(s))
		_mann[key] = [out, skin]
		src.free()
	var data: Array = _mann[key]
	var skin2: Skin = data[1].duplicate()
	for i in skin2.get_bind_count():
		var bi := skel.find_bone(skin2.get_bind_name(i))
		if bi >= 0:
			skin2.set_bind_pose(i, skel.get_bone_global_rest(bi).affine_inverse())
	var m := MeshInstance3D.new()
	m.name = "Mannequin"
	m.mesh = data[0]
	skel.add_child(m)
	m.skin = skin2
	m.skeleton = NodePath("..")

static var _tattoo: Texture2D
static func _tattoo_tex() -> Texture2D:
	if _tattoo:
		return _tattoo
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img.fill(Color(0.62, 0.62, 0.62))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 70:
		var x := rng.randf_range(0, 512); var y := rng.randf_range(0, 512)
		var fresh := rng.randf() < 0.3
		var c := Color(0.32, 0.1, 0.1) if fresh else Color(0.15, 0.16, 0.14)
		var a := rng.randf_range(0, TAU)
		for k in 60:
			a += rng.randf_range(-0.25, 0.25)
			x = fposmod(x + cos(a) * 2.0, 512.0); y = fposmod(y + sin(a) * 2.0, 512.0)
			for dx in 3:
				for dy in 3:
					img.set_pixel(int(x + dx) % 512, int(y + dy) % 512, c)
	_tattoo = ImageTexture.create_from_image(img)
	return _tattoo

static func flat_mat(c: Color, rough := 0.8, emission := Color.BLACK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOTH
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("inner_col", Vector3(c.r, c.g, c.b) * 0.7)
	m.set_shader_parameter("tatter", 0.0)
	return m

# ---------------------------------------------------------------------
#  Cabeça e cabelo
# ---------------------------------------------------------------------
static func _build_head(rig: CharRig, sp: Dictionary) -> void:
	var h: Dictionary = sp.get("head", {})
	var skel := rig.skel
	var hb := skel.find_bone("Head")
	var r: Vector3 = h.get("r", Vector3(0.086, 0.108, 0.096))
	var head := Node3D.new()
	head.name = "AnimeHead"
	var origin: Vector3 = skel.get_bone_global_rest(hb).origin + Vector3(0, 0.088, 0.022) + h.get("offset", Vector3.ZERO)
	rig.attach_model(head, "Head", Transform3D(Basis(), origin))
	rig.head_node = head
	var hm := MeshInstance3D.new()
	hm.mesh = Geo.head_mesh(r)
	var mat := ShaderMaterial.new()
	mat.shader = HEAD
	var skin: Color = h.get("skin", sp.get("skin", Color(0.9, 0.75, 0.65)))
	mat.set_shader_parameter("skin_col", Vector3(skin.r, skin.g, skin.b))
	if h.get("face", "") != "":
		var f1 := load("res://assets/faces/%s_n.png" % h.face)
		var f2 := load("res://assets/faces/%s_a.png" % h.face)
		if h.get("angry", false):
			mat.set_shader_parameter("face_tex", f2)
		else:
			mat.set_shader_parameter("face_tex", f1)
		mat.set_shader_parameter("face_tex2", f2)
	mat.set_shader_parameter("face_size", Vector2(r.x * 2.1, r.x * 2.1))
	mat.set_shader_parameter("face_center", Vector2(0, -r.y * 0.1))
	mat.set_shader_parameter("blush", h.get("blush", 0.15))
	var bc: Color = h.get("blush_col", Color(1, 0.45, 0.45))
	mat.set_shader_parameter("blush_col", Vector3(bc.r, bc.g, bc.b))
	var eg: Color = h.get("eye_glow", Color.BLACK)
	mat.set_shader_parameter("eye_glow", Vector3(eg.r, eg.g, eg.b))
	var ol := ShaderMaterial.new()
	ol.shader = OUTLINE
	ol.set_shader_parameter("width", 0.0035)
	mat.next_pass = ol
	hm.material_override = mat
	head.add_child(hm)
	rig.head_mat = mat
	rig.mats.append(mat)
	# pescoço
	var nb := skel.find_bone("neck_01")
	var npos := skel.get_bone_global_rest(nb).origin
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r.x * 0.42; cm.bottom_radius = r.x * 0.5; cm.height = (origin.y - npos.y) + 0.02
	neck.mesh = cm
	var skin_m := _skin_mat(skin)
	neck.material_override = skin_m
	rig.attach_model(neck, "neck_01", Transform3D(Basis(), npos + Vector3(0, cm.height * 0.5 - 0.02, 0.01)))
	rig.mats.append(skin_m)
	# cabelo (camadas)
	for layer in sp.get("hair", []):
		var key: String = layer[0] + str(r)
		if not _hair_cache.has(key):
			var st := hair_style(layer[0])
			if st.get("cap", true) == false:
				st["no_cap"] = true
			_hair_cache[key] = _hair_mesh(st, r)
		var hmi := MeshInstance3D.new()
		hmi.mesh = _hair_cache[key]
		var hmat := ShaderMaterial.new()
		hmat.shader = HAIR
		var c1: Color = layer[1]; var c2: Color = layer[2]
		hmat.set_shader_parameter("base_col", Vector3(c1.r, c1.g, c1.b))
		hmat.set_shader_parameter("tip_col", Vector3(c2.r, c2.g, c2.b))
		hmat.set_shader_parameter("shine", layer[3])
		var hol := ShaderMaterial.new(); hol.shader = OUTLINE; hol.set_shader_parameter("width", 0.0025)
		hmat.next_pass = hol
		hmi.material_override = hmat
		head.add_child(hmi)
		rig.mats.append(hmat)
	# orelhas
	if sp.has("ears"):
		for s in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			e.mesh = Geo.ear_mesh(s, sp.ears.len, r, sp.ears.get("tilt", 0.4))
			e.material_override = skin_m
			head.add_child(e)
	if sp.get("horns", "") == "ram":
		for s in [-1.0, 1.0]:
			var hn := MeshInstance3D.new()
			hn.mesh = Geo.ram_horn(s, 1.0)
			hn.material_override = flat_mat(sp.get("horn_col", Color(0.15, 0.13, 0.2)))
			hn.position = Vector3(s * r.x * 0.62, r.y * 0.62, -0.01)
			head.add_child(hn)
	elif sp.get("horns", "") == "dragon":
		for s in [-1.0, 1.0]:
			var hn := MeshInstance3D.new()
			hn.mesh = Geo.dragon_horn(s)
			hn.material_override = flat_mat(sp.get("horn_col", Color(0.25, 0.2, 0.15)))
			hn.position = Vector3(s * r.x * 0.55, r.y * 0.72, -0.01)
			head.add_child(hn)
	if sp.get("antlers", false):
		for s in [-1.0, 1.0]:
			var an := MeshInstance3D.new()
			an.mesh = Geo.antler(s)
			an.material_override = flat_mat(Color(0.3, 0.2, 0.12))
			an.position = Vector3(s * r.x * 0.5, r.y * 0.75, -0.005)
			head.add_child(an)
	if sp.get("flower", false):
		var fl := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.028; sm.height = 0.02
		fl.mesh = sm
		fl.material_override = flat_mat(Color(0.97, 0.96, 0.92))
		fl.position = Vector3(r.x * 0.75, r.y * 0.55, 0.035)
		head.add_child(fl)
	if sp.get("tusks", false):
		for s in [-1.0, 1.0]:
			var t := MeshInstance3D.new()
			t.mesh = Geo.tusk(s)
			t.material_override = flat_mat(Color(0.93, 0.9, 0.8))
			head.add_child(t)
	if sp.get("twig", false):
		var tw := MeshInstance3D.new()
		var tcm := CylinderMesh.new(); tcm.top_radius = 0.0035; tcm.bottom_radius = 0.005; tcm.height = 0.075
		tw.mesh = tcm
		tw.material_override = flat_mat(Color(0.45, 0.32, 0.18))
		tw.position = Vector3(r.x * 0.32, -r.y * 0.52, r.z * 0.92)
		tw.rotation = Vector3(1.35, 0.0, 0.9)
		head.add_child(tw)
	if sp.has("mask"):
		var mk := MeshInstance3D.new()
		mk.mesh = Geo.mask_mesh(r)
		mk.material_override = flat_mat(sp.mask)
		head.add_child(mk)

static func _hair_mesh(st: Dictionary, r: Vector3) -> ArrayMesh:
	if st.get("no_cap", false):
		st["cap_bottom"] = 0.0001
	return Geo.hair_mesh(st, r)

static func _skin_mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("skin_mode", true)
	m.set_shader_parameter("skin_col", c)
	m.set_shader_parameter("roughness_v", 0.65)
	return m

# ---------------------------------------------------------------------
#  Roupas extras, capas, armas
# ---------------------------------------------------------------------
static func _bone_y(skel: Skeleton3D, b: String) -> Vector3:
	return skel.get_bone_global_rest(skel.find_bone(b)).origin

static func _build_extras(rig: CharRig, sp: Dictionary) -> void:
	var skel := rig.skel
	var s3 := _bone_y(skel, "spine_03")
	var pel := _bone_y(skel, "pelvis")
	var colliders := [
		{"bone": "spine_03", "local": s3 + Vector3(0, 0.02, -0.02), "r": 0.17},
		{"bone": "spine_01", "local": _bone_y(skel, "spine_01") + Vector3(0, 0, -0.01), "r": 0.16},
		{"bone": "pelvis", "local": pel + Vector3(0, -0.03, 0), "r": 0.17},
		{"bone": "thigh_l", "local": _bone_y(skel, "thigh_l").lerp(_bone_y(skel, "calf_l"), 0.5), "r": 0.1},
		{"bone": "thigh_r", "local": _bone_y(skel, "thigh_r").lerp(_bone_y(skel, "calf_r"), 0.5), "r": 0.1},
		{"bone": "calf_l", "local": _bone_y(skel, "calf_l").lerp(_bone_y(skel, "foot_l"), 0.5), "r": 0.08},
		{"bone": "calf_r", "local": _bone_y(skel, "calf_r").lerp(_bone_y(skel, "foot_r"), 0.5), "r": 0.08},
	]
	# capas
	for c in sp.get("cloaks", []):
		var w: float = c.w
		var pins := []
		var n := 7
		for j in n:
			var t := float(j) / (n - 1) * 2.0 - 1.0
			var local := s3 + Vector3(t * w * 0.5, 0.17 - abs(t) * 0.04, -0.14 + (1.0 - t * t) * -0.04 + abs(t) * 0.06)
			var bone := "spine_03"
			if abs(t) > 0.6:
				bone = "clavicle_l" if t > 0 else "clavicle_r"
			pins.append({"bone": bone, "local": local})
		var cl := Cloth.new()
		var m := ShaderMaterial.new()
		m.shader = CLOTH
		var col: Color = c.col; var inner: Color = c.get("inner", c.col)
		m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
		m.set_shader_parameter("inner_col", Vector3(inner.r, inner.g, inner.b))
		m.set_shader_parameter("tatter", c.get("tatter", 0.18))
		if c.get("fur", false):
			m.set_shader_parameter("fur", 1.0)
			m.set_shader_parameter("use_pattern", true)
			m.set_shader_parameter("pattern", _rune_pattern(inner))
		elif c.get("waves", false):
			m.set_shader_parameter("use_pattern", true)
			m.set_shader_parameter("pattern", _wave_pattern(col))
		cl.material_override = m
		rig.add_child(cl)
		cl.setup(skel, rig, pins, c.len * sp.get("scale", 1.0), colliders, 7, 9)
		rig.cloths.append(cl)
		rig.mats.append(m)
		if c.get("collar", false):
			var tor := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.105; tm.outer_radius = 0.14
			tor.mesh = tm
			tor.material_override = flat_mat(c.get("collar_col", col))
			tor.scale = Vector3(1.0, 0.6, 0.85)
			rig.attach_model(tor, "spine_03", Transform3D(Basis(), s3 + Vector3(0, 0.19, -0.02)))
	# saias/tabardos (presos à pelve)
	for sk in sp.get("skirts", []):
		var pins := []
		var n := 6
		var w: float = sk.w
		for j in n:
			var t := float(j) / (n - 1) * 2.0 - 1.0
			var z := (0.12 if sk.front else -0.13) - (0.0 if sk.front else 0.0)
			pins.append({"bone": "pelvis", "local": pel + Vector3(t * w * 0.5, 0.06, z * (1.0 - t * t * 0.3))})
		var cl := Cloth.new()
		var m := ShaderMaterial.new(); m.shader = CLOTH
		var col: Color = sk.col
		m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
		m.set_shader_parameter("inner_col", Vector3(col.r, col.g, col.b) * 0.7)
		m.set_shader_parameter("tatter", 0.3)
		cl.material_override = m
		rig.add_child(cl)
		cl.damping = 0.9
		cl.setup(skel, rig, pins, sk.len * sp.get("scale", 1.0), colliders.slice(2), 6, 7)
		rig.cloths.append(cl)
		rig.mats.append(m)
	# faixa na cintura
	if sp.has("sash"):
		var tor := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.135; tm.outer_radius = 0.19
		tor.mesh = tm
		tor.material_override = flat_mat(sp.sash)
		tor.scale = Vector3(1.05, 0.55, 0.85)
		rig.attach_model(tor, "pelvis", Transform3D(Basis(), pel + Vector3(0, 0.12, 0.0)))
		var tail := Cloth.new()
		var m := ShaderMaterial.new(); m.shader = CLOTH
		m.set_shader_parameter("col", Vector3(sp.sash.r, sp.sash.g, sp.sash.b))
		m.set_shader_parameter("inner_col", Vector3(sp.sash.r, sp.sash.g, sp.sash.b) * 0.7)
		m.set_shader_parameter("tatter", 0.35)
		tail.material_override = m
		rig.add_child(tail)
		tail.setup(skel, rig, [{"bone": "pelvis", "local": pel + Vector3(0.1, 0.1, 0.1)}, {"bone": "pelvis", "local": pel + Vector3(0.15, 0.1, 0.06)}, {"bone": "pelvis", "local": pel + Vector3(0.18, 0.1, 0.0)}], 0.55, colliders.slice(2), 3, 6)
		rig.cloths.append(tail)
	if sp.has("scarf"):
		var sc: Color = sp.scarf
		var tor := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.075; tm.outer_radius = 0.112
		tor.mesh = tm
		tor.material_override = flat_mat(sc)
		tor.scale = Vector3(1.0, 0.9, 0.95)
		rig.attach_model(tor, "spine_03", Transform3D(Basis(), s3 + Vector3(0, 0.22, 0.0)))
		var tail := Cloth.new()
		var m := ShaderMaterial.new(); m.shader = CLOTH
		m.set_shader_parameter("col", Vector3(sc.r, sc.g, sc.b))
		m.set_shader_parameter("inner_col", Vector3(sc.r, sc.g, sc.b) * 0.6)
		m.set_shader_parameter("tatter", 0.15)
		m.set_shader_parameter("use_pattern", true)
		m.set_shader_parameter("pattern", _plaid_pattern(sc))
		tail.material_override = m
		rig.add_child(tail)
		tail.setup(skel, rig, [{"bone": "spine_03", "local": s3 + Vector3(-0.02, 0.2, -0.1)}, {"bone": "spine_03", "local": s3 + Vector3(0.04, 0.2, -0.11)}, {"bone": "spine_03", "local": s3 + Vector3(0.1, 0.19, -0.1)}], 0.75, colliders, 3, 8)
		rig.cloths.append(tail)
		rig.mats.append(m)
	if sp.get("katana_hip", false):
		var hip := _katana(true)
		var node := rig.attach_model(hip, "pelvis", Transform3D(Basis(Vector3.RIGHT, -1.93), pel + Vector3(0.19, 0.06, 0.08)))
		rig.set_meta("katana_hip", node)
	if sp.has("wrap"):
		for k in 3:
			var tor := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.135 - k * 0.004; tm.outer_radius = 0.165 - k * 0.004
			tor.mesh = tm
			tor.material_override = flat_mat(sp.wrap)
			tor.scale = Vector3(1.0, 0.7, 0.8)
			rig.attach_model(tor, "spine_03", Transform3D(Basis(), s3 + Vector3(0, -0.02 - k * 0.045, 0.01)))
	if sp.has("wristbands") or sp.has("gloves"):
		var c: Color = sp.get("wristbands", sp.get("gloves"))
		for side in ["l", "r"]:
			var la := _bone_y(skel, "lowerarm_" + side)
			var hd := _bone_y(skel, "hand_" + side)
			var tor := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.042; cm.bottom_radius = 0.046; cm.height = 0.09 if sp.has("wristbands") else 0.12
			tor.mesh = cm
			tor.material_override = flat_mat(c)
			rig.attach_model(tor, "lowerarm_" + side, Transform3D(Basis(Vector3(0, 0, 1), PI / 2), la.lerp(hd, 0.8)))
			if sp.has("gloves"):
				var gl := MeshInstance3D.new()
				var gs := SphereMesh.new(); gs.radius = 0.048; gs.height = 0.09
				gl.mesh = gs
				gl.material_override = flat_mat(c)
				rig.attach_model(gl, "hand_" + side, Transform3D(Basis(), hd + Vector3(0.04 * (1 if side == "l" else -1), 0, 0)))
	if sp.has("fur_cuffs"):
		for side in ["l", "r"]:
			var cf := _bone_y(skel, "calf_" + side)
			var ft := _bone_y(skel, "foot_" + side)
			var tor := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.05; tm.outer_radius = 0.1
			tor.mesh = tm
			tor.material_override = flat_mat(sp.fur_cuffs)
			rig.attach_model(tor, "calf_" + side, Transform3D(Basis(), cf.lerp(ft, 0.3)))
	if sp.get("belt_pouch", false):
		var bx := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.1, 0.11, 0.05)
		bx.mesh = bm
		bx.material_override = flat_mat(Color(0.4, 0.25, 0.14))
		rig.attach_model(bx, "pelvis", Transform3D(Basis(Vector3.UP, 0.4), pel + Vector3(0.15, 0.04, 0.08)))
	if sp.has("apron"):
		var ap := MeshInstance3D.new()
		var pm := BoxMesh.new(); pm.size = Vector3(0.34, 0.6, 0.015)
		ap.mesh = pm
		ap.material_override = flat_mat(sp.apron)
		rig.attach_model(ap, "pelvis", Transform3D(Basis(), pel + Vector3(0, -0.15, 0.16)))
	if sp.has("harness"):
		var hr := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.19; tm.outer_radius = 0.215
		hr.mesh = tm
		hr.material_override = flat_mat(sp.harness)
		rig.attach_model(hr, "spine_03", Transform3D(Basis(Vector3(0, 0, 1), 0.8) * Basis().scaled(Vector3(1, 1, 0.6)), s3 + Vector3(0, -0.02, 0)))
	if sp.get("pauldron", false):
		var pd: Node3D = scene(CH + "Male_Ranger_Acc_Pauldron.gltf").instantiate()
		var pmi: MeshInstance3D = pd.find_child("Male_Ranger_Acc_Pauldron", true, false)
		if pmi:
			pmi.get_parent().remove_child(pmi)
			skel.add_child(pmi)
			pmi.skeleton = NodePath("..")
			var m := ShaderMaterial.new(); m.shader = TOON
			m.set_shader_parameter("albedo_tex", load(CH + "T_Ranger_3_BaseColor.png"))
			m.set_shader_parameter("tint", Vector3(0.9, 0.7, 0.55))
			pmi.material_override = m
			rig.mats.append(m)
		pd.free()
	if sp.get("spikes", false):
		for k in 4:
			var sp2 := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.018; cm.height = 0.09
			sp2.mesh = cm
			sp2.material_override = flat_mat(Color(0.55, 0.4, 0.25))
			var ua := _bone_y(skel, "upperarm_l")
			rig.attach_model(sp2, "upperarm_l", Transform3D(Basis(Vector3(0, 0, 1), -0.4 + k * 0.12), ua + Vector3(0.02 + k * 0.035, 0.09 - k * 0.01, -0.02)))
	if sp.has("tail"):
		_build_tail(rig, sp)
	if sp.get("hunch", false):
		rig.pose.set_offset("spine_02", Vector3(22, 0, 0), 1.0)
		rig.pose.set_offset("neck_01", Vector3(-12, 0, 0), 1.0)
	if sp.get("cane", false):
		var cn := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.014; cm.height = 0.95
		cn.mesh = cm
		cn.material_override = flat_mat(Color(0.3, 0.2, 0.12))
		var hd := _bone_y(skel, "hand_r")
		rig.attach_model(cn, "hand_r", Transform3D(Basis(), hd + Vector3(-0.05, -0.45, 0.03)))
	if sp.get("crystal", false):
		var cr := MeshInstance3D.new()
		var pm := PrismMesh.new(); pm.size = Vector3(0.05, 0.08, 0.03)
		cr.mesh = pm
		var mm := StandardMaterial3D.new(); mm.albedo_color = Color(1, 0.1, 0.2); mm.emission_enabled = true; mm.emission = Color(1, 0.05, 0.15); mm.emission_energy_multiplier = 3.0
		cr.material_override = mm
		rig.attach_model(cr, "spine_03", Transform3D(Basis(), s3 + Vector3(0, 0.08, 0.15)))
		rig.set_meta("crystal", cr)
	if sp.get("back_sword", false):
		var sw: Node3D = normalize_prop(scene("res://assets/weapons/sword_E.gltf").instantiate(), 1.1, 0.1)
		rig.attach_model(sw, "spine_03", Transform3D(Basis(Vector3(0, 0, 1), 2.6), s3 + Vector3(0.1, -0.1, -0.17)))
	# armas
	if sp.has("weapon"):
		rig.weapon = _weapon(rig, sp.weapon, "hand_r")
	if sp.has("weapon_l"):
		rig.weapon2 = _weapon(rig, sp.weapon_l, "hand_l")
	if sp.get("ukulele", false):
		var u := _ukulele()
		rig.ukulele_back = Transform3D(Basis(Vector3(0, 0, 1), 0.5) * Basis(Vector3.UP, PI), s3 + Vector3(0.06, -0.08, -0.2))
		rig.ukulele_front = Transform3D(Basis(Vector3(0, 0, 1), 1.2) * Basis(Vector3.RIGHT, 0.15), s3 + Vector3(-0.02, -0.12, 0.22))
		rig.ukulele = rig.attach_model(u, "spine_03", rig.ukulele_back)

## Envolve um modelo KayKit num pivô: escala para o comprimento desejado e posiciona a
## empunhadura (fração do comprimento a partir da base) na origem.
static func normalize_prop(model: Node3D, length: float, grip_frac := 0.12) -> Node3D:
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = (mi as Node3D).transform
		var p: Node = mi.get_parent()
		while p and p != model:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s := length / maxf(longest, 0.001)
	var pivot := Node3D.new()
	pivot.add_child(model)
	model.scale = Vector3.ONE * s
	var center := aabb.get_center()
	model.position = -Vector3(center.x, aabb.position.y + aabb.size.y * grip_frac, center.z) * s
	return pivot

const WEAPON_LEN := {"dagger_A": 0.36, "dagger_B": 0.36, "sword_A": 0.95, "sword_B": 0.95, "sword_C": 0.95, "sword_D": 1.0, "sword_E": 1.0, "axe_A": 0.8, "axe_B": 0.85, "axe_C": 0.85, "hammer_A": 0.8, "hammer_B": 0.85, "hammer_C": 0.85, "spear_A": 1.7, "staff_A": 1.6}

static func _weapon(rig: CharRig, w: String, hand: String) -> Node3D:
	var skel := rig.skel
	var hp := _bone_y(skel, hand)
	var side := 1.0 if hand == "hand_l" else -1.0
	var node: Node3D
	var grip := Vector3(side * 0.075, -0.015, 0.01)
	var basis := Basis(Vector3.RIGHT, PI / 2)       # lâmina (+Y do modelo) para a frente (+Z)
	match w:
		"kael_dagger":
			node = normalize_prop(scene("res://assets/weapons/dagger_A.gltf").instantiate(), 0.42, 0.14)
			var glow := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.01, 0.2, 0.016)
			glow.mesh = bm
			var gm := StandardMaterial3D.new(); gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.albedo_color = Color(0.4, 0.9, 1.0); gm.emission_enabled = true; gm.emission = Color(0.3, 0.85, 1.0); gm.emission_energy_multiplier = 2.0
			glow.material_override = gm
			glow.position = Vector3(0, 0.2, 0.0)
			node.add_child(glow)
			node.set_meta("glow", gm)
		"cleaver":
			node = normalize_prop(scene("res://assets/weapons/axe_B.gltf").instantiate(), 0.8, 0.1)
		"katana":
			node = _katana(false)
		"bow":
			node = normalize_prop(scene("res://assets/weapons/bow_A_withString.gltf").instantiate(), 1.15, 0.5)
			basis = Basis.IDENTITY
			grip = Vector3(side * 0.07, 0.0, 0.0)
		_:
			node = normalize_prop(scene("res://assets/weapons/%s.gltf" % w).instantiate(), WEAPON_LEN.get(w, 0.9), 0.1)
	return rig.attach_model(node, hand, Transform3D(basis, hp + grip))

static func _ukulele() -> Node3D:
	var u := Node3D.new()
	var wood := flat_mat(Color(0.55, 0.33, 0.17))
	var dark := flat_mat(Color(0.3, 0.17, 0.08))
	for d in [[0.1, Vector3(0, 0, 0)], [0.08, Vector3(0, 0.12, 0)]]:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = d[0]; sm.height = d[0] * 2
		b.mesh = sm
		b.scale = Vector3(1, 1, 0.35)
		b.position = d[1]
		b.material_override = wood
		u.add_child(b)
	var nk := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.035, 0.3, 0.025)
	nk.mesh = bm; nk.position = Vector3(0, 0.32, 0); nk.material_override = dark
	u.add_child(nk)
	var hd := MeshInstance3D.new()
	var bm2 := BoxMesh.new(); bm2.size = Vector3(0.05, 0.08, 0.025)
	hd.mesh = bm2; hd.position = Vector3(0, 0.5, 0); hd.material_override = dark
	u.add_child(hd)
	var st := MeshInstance3D.new()
	var bm3 := BoxMesh.new(); bm3.size = Vector3(0.022, 0.44, 0.002)
	st.mesh = bm3; st.position = Vector3(0, 0.25, 0.04)
	var sm3 := StandardMaterial3D.new(); sm3.albedo_color = Color(0.95, 0.92, 0.8); sm3.emission_enabled = true; sm3.emission = Color(0.9, 0.85, 0.6); sm3.emission_energy_multiplier = 0.2
	st.material_override = sm3
	u.add_child(st)
	u.set_meta("strings", sm3)
	return u

## Katana feita em código: lâmina levemente curva (+Y), tsuba e cabo trançado.
## `sheathed` = dentro da bainha laqueada (só o cabo aparece).
static func _katana(sheathed: bool) -> Node3D:
	var root := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.86, 0.92)
	steel.metallic = 0.9
	steel.roughness = 0.15
	steel.emission_enabled = true
	steel.emission = Color(0.25, 0.3, 0.38)
	steel.emission_energy_multiplier = 0.35
	var dark := flat_mat(Color(0.06, 0.05, 0.06))
	var wrap := flat_mat(Color(0.12, 0.1, 0.16))
	var gold := flat_mat(Color(0.65, 0.5, 0.25))
	# cabo
	var hd := MeshInstance3D.new()
	var hc := CylinderMesh.new(); hc.top_radius = 0.016; hc.bottom_radius = 0.017; hc.height = 0.24; hc.radial_segments = 8
	hd.mesh = hc
	hd.material_override = wrap
	hd.position = Vector3(0, -0.06, 0)
	root.add_child(hd)
	# tsuba
	var ts := MeshInstance3D.new()
	var tc := CylinderMesh.new(); tc.top_radius = 0.042; tc.bottom_radius = 0.042; tc.height = 0.012; tc.radial_segments = 12
	ts.mesh = tc
	ts.material_override = gold
	ts.position = Vector3(0, 0.065, 0)
	root.add_child(ts)
	if sheathed:
		var sc := MeshInstance3D.new()
		var scm := CylinderMesh.new(); scm.top_radius = 0.02; scm.bottom_radius = 0.024; scm.height = 0.8; scm.radial_segments = 8
		sc.mesh = scm
		sc.material_override = dark
		sc.position = Vector3(0, 0.47, 0)
		root.add_child(sc)
		return root
	# lâmina: fita fina levemente inclinada + ponta
	var bl := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.007, 0.72, 0.03)
	bl.mesh = bm
	bl.material_override = steel
	bl.rotation.x = -0.04
	bl.position = Vector3(0, 0.43, 0.012)
	root.add_child(bl)
	var tip := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.03, 0.08, 0.007)
	tip.mesh = pm
	tip.material_override = steel
	tip.rotation = Vector3(-0.04, PI / 2, 0)
	tip.position = Vector3(0, 0.825, 0.028)
	root.add_child(tip)
	return root

static var _wave_tex: Texture2D
## Ondas negras sobre o tecido (haori do Yuto).
static func _wave_pattern(c: Color) -> Texture2D:
	if _wave_tex:
		return _wave_tex
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(c)
	var ink := Color(0.06, 0.04, 0.04)
	for y in 128:
		for x in 128:
			var fx := float(x % 32)
			var row := y % 32
			var wave := 16.0 + sin(fx / 32.0 * TAU) * 5.0
			if abs(row - wave) < 1.6 or abs(row - wave - 6.0) < 1.0:
				img.set_pixel(x, y, ink)
	_wave_tex = ImageTexture.create_from_image(img)
	return _wave_tex

static var _plaid_tex: Texture2D
## Xadrez do cachecol.
static func _plaid_pattern(c: Color) -> Texture2D:
	if _plaid_tex:
		return _plaid_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var k := c
			if x % 16 < 3 or y % 16 < 3:
				k = c.darkened(0.55)
			elif x % 16 == 8 or y % 16 == 8:
				k = c.lightened(0.35)
			img.set_pixel(x, y, k)
	_plaid_tex = ImageTexture.create_from_image(img)
	return _plaid_tex

static var _pattern: Texture2D
static func _rune_pattern(c: Color) -> Texture2D:
	if _pattern:
		return _pattern
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(c)
	var light := c.lightened(0.6)
	for y in 128:
		for x in 128:
			var cx := x % 32 - 16; var cy := y % 32 - 16
			var d := sqrt(cx * cx + cy * cy)
			if abs(d - 9.0) < 1.2 or (abs(cx) < 1 and abs(cy) < 4):
				img.set_pixel(x, y, light)
	_pattern = ImageTexture.create_from_image(img)
	return _pattern

## Cauda (lobo do Viktor / dragão do Krauser): corrente de segmentos com mola.
static func _build_tail(rig: CharRig, sp: Dictionary) -> void:
	var tail := TailChain.new()
	tail.dragon = sp.get("dragon_tail", false)
	tail.color = sp.tail
	rig.add_child(tail)
	tail.setup(rig)
