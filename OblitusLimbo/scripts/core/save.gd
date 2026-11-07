extends Node
## Progresso e opções persistentes (user://save.cfg).

const PATH := "user://save.cfg"
var unlocked := 3
var ch := 0
var seg := 0
var opts := {"master": 0.8, "music": 0.6, "sfx": 0.9, "sens": 1.0, "quality": "med", "diff": 1.0, "fullscreen": true, "vsync": true, "invert_y": false, "story_char": "kiana"}

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		unlocked = cf.get_value("progress", "unlocked", unlocked)
		ch = cf.get_value("progress", "ch", 0)
		seg = cf.get_value("progress", "seg", 0)
		var o: Dictionary = cf.get_value("options", "opts", {})
		for k in o:
			opts[k] = o[k]

func write() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "ch", ch)
	cf.set_value("progress", "seg", seg)
	cf.set_value("options", "opts", opts)
	cf.save(PATH)
