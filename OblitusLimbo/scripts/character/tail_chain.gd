class_name TailChain
extends Node3D
## Cauda com física de mola: corrente de cápsulas que segue a pelve com atraso.

var rig: CharRig
var dragon := false
var color := Color(0.8, 0.8, 0.85)
var n := 9
var pts := PackedVector3Array()
var vel := PackedVector3Array()
var segs: Array[MeshInstance3D] = []
var seg_len := 0.09
var _t := 0.0

func setup(r: CharRig) -> void:
	rig = r

func _ready() -> void:
	if rig == null: return
	top_level = true
	global_transform = Transform3D.IDENTITY
	seg_len = 0.12 if dragon else 0.075
	n = 11 if dragon else 8
	var mat := CharFactory.flat_mat(color)
	if dragon:
		mat.set_shader_parameter("fur", 0.0)
	else:
		mat.set_shader_parameter("fur", 1.0)
	for i in n - 1:
		var m := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		var t := float(i) / (n - 1)
		var rad: float = (lerp(0.07, 0.015, t) if dragon else (0.045 + sin(t * PI) * 0.035))
		cm.radius = rad
		cm.height = max(seg_len + rad * 1.6, rad * 2.0)
		m.mesh = cm
		m.material_override = mat
		add_child(m)
		segs.append(m)
	rig.mats.append(mat)
	reset()
	_ok = true

var _ok := false

func _root_pos() -> Vector3:
	var sk := rig.skel
	var pel := sk.get_bone_global_rest(sk.find_bone("pelvis")).origin
	return rig.bone_model_point("pelvis", pel + Vector3(0, -0.04, -0.14))

func _back_dir() -> Vector3:
	return -(rig.global_transform.basis.z).normalized()

func reset() -> void:
	pts.resize(n)
	vel.resize(n)
	var p := _root_pos()
	var d := (_back_dir() + Vector3(0, -0.8 if not dragon else -0.4, 0)).normalized()
	for i in n:
		pts[i] = p + d * seg_len * i
		vel[i] = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not _ok:
		return
	_t += delta
	pts[0] = _root_pos()
	if pts[1].distance_to(pts[0]) > 2.0:
		reset()
	var back := _back_dir()
	var sway := rig.global_transform.basis.x * sin(_t * (2.5 if dragon else 4.0)) * 0.6
	for i in range(1, n):
		var want_dir := (back * (1.0 if dragon else 0.5) + Vector3(0, -0.35 if dragon else -1.0, 0) + sway * float(i) / n).normalized()
		if dragon:
			want_dir.y = max(want_dir.y, -0.25 + float(i) * 0.0)
		var target := pts[i - 1] + want_dir * seg_len
		vel[i] = vel[i] * 0.82 + (target - pts[i]) * delta * 60.0
		pts[i] += vel[i] * delta * 8.0
		var d := pts[i] - pts[i - 1]
		pts[i] = pts[i - 1] + d.normalized() * seg_len
		var floor_y := rig.global_position.y + 0.04
		pts[i].y = max(pts[i].y, floor_y)
	for i in n - 1:
		var a := pts[i]; var b := pts[i + 1]
		var m := segs[i]
		var dir := (b - a).normalized()
		var up := dir
		var x := up.cross(Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(up).normalized()
		m.global_transform = Transform3D(Basis(x, up, z), (a + b) * 0.5)
