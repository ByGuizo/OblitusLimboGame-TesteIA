extends Node3D
var p: GPUParticles3D
var t := 0.0
func _ready():
	var cam := Camera3D.new(); cam.position = Vector3(0, 1, 6); add_child(cam)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.1,0.1,0.15); env.environment = e; add_child(env)
	p = GPUParticles3D.new()
	p.amount = 500
	p.lifetime = 1.0
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -2, 0)
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.15, 0.15)
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.vertex_color_use_as_albedo = true; m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	p.local_coords = false
	add_child(p)
func _process(d):
	t += d
	for i in 5:
		var xf := Transform3D(Basis(), Vector3(randf_range(-2, 2), randf_range(0, 2), 0))
		p.emit_particle(xf, Vector3(0, 2, 0), Color(randf(), 0.5, 1.0, 1.0), Color(), GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR)
