class_name Npc
extends Actor
## Personagem neutro (diálogos, figurantes, cinemáticas).

var wander := 0.0
var home := Vector3.ZERO
var wt := 0.0
var goal = null
var idle_anim := ""

func setup_npc(id: String, o := {}) -> void:
	setup(id, {"team": "neutral", "hp": 999.0, "radius": o.get("radius", 0.4), "pos": o.get("pos", Vector3.ZERO), "yaw": o.get("yaw", 0.0), "name": o.get("name", id), "rig": o.get("rig", {})})
	team = "neutral"
	wander = o.get("wander", 0.0)
	home = position
	wt = randf() * 5.0
	idle_anim = o.get("anim", "")
	collision_layer = 2

func _ready() -> void:
	if idle_anim != "":
		rig.play(idle_anim, {"loop": true, "blend": 0.0})

func _physics_process(delta: float) -> void:
	if wander > 0.0 and not Game.cine and not scripted:
		wt -= delta
		if wt <= 0.0:
			wt = randf_range(4.0, 9.0)
			goal = home + Vector3(randf_range(-1, 1) * wander, 0, randf_range(-1, 1) * wander)
		if goal != null:
			var to: Vector3 = goal - global_position
			to.y = 0
			if to.length() > 0.3:
				move_dir(to.normalized(), 1.3, delta, 4.0)
				face_to(atan2(to.x, to.z), delta, 4.0)
			else:
				brake(delta)
	else:
		brake(delta)
	base_update(delta)
