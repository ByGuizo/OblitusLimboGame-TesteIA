class_name Cloth
extends MeshInstance3D
## Capa/pano simulado (Verlet) preso aos ossos do personagem, com colisão contra esferas
## (pelve, coxas, canelas, tronco) e vento. Malha renderizada com o dobro da resolução.

var skel: Skeleton3D
var cols := 7
var rows := 9
var pins: Array = []          # [{bone, local(Vector3 no espaço de repouso do modelo)}] por coluna
var colliders: Array = []     # [{bone, local, r}]
var pos := PackedVector3Array()
var prev := PackedVector3Array()
var rest_h := 0.07
var rest_v := 0.11
var damping := 0.94
var gravity := 9.0
var wind_strength := 0.6
var stiff_iters := 3
var _arr_mesh := ArrayMesh.new()
var _indices := PackedInt32Array()
var _uvs := PackedVector2Array()
var _rc := 13
var _rr := 17
var _bone_cache := {}
var _active := true
var _t := 0.0
var _model_root: Node3D
var _tick := 0
var _accum := 0.0
var _dirty := false

func setup(skeleton: Skeleton3D, model_root: Node3D, p_pins: Array, length: float, p_colliders: Array, p_cols := 7, p_rows := 9) -> void:
	skel = skeleton
	_model_root = model_root
	cols = p_cols
	rows = p_rows
	pins = p_pins
	colliders = p_colliders
	_length = length
	if is_inside_tree():
		_init_sim()

var _length := 1.0
var _ready_done := false

func _ready() -> void:
	if skel and not _ready_done:
		_init_sim()

func _init_sim() -> void:
	_ready_done = true
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _arr_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	var a := _pin_world(0)
	var b := _pin_world(cols - 1)
	rest_h = a.distance_to(b) / (cols - 1) * 1.08
	rest_v = _length / (rows - 1)
	_rc = (cols - 1) * 2 + 1
	_rr = (rows - 1) * 2 + 1
	for i in _rr:
		for j in _rc:
			_uvs.append(Vector2(float(j) / (_rc - 1), float(i) / (_rr - 1)))
	for i in _rr - 1:
		for j in _rc - 1:
			var a0 := i * _rc + j
			_indices.append_array([a0, a0 + _rc, a0 + 1, a0 + 1, a0 + _rc, a0 + _rc + 1])
	reset()

func _xf(bone: String, local: Vector3) -> Vector3:
	var bi: int = _bone_cache.get(bone, -2)
	if bi == -2:
		bi = skel.find_bone(bone)
		_bone_cache[bone] = bi
	var pose := skel.get_bone_global_pose(bi)
	var rest := skel.get_bone_global_rest(bi)
	return skel.global_transform * (pose * (rest.affine_inverse() * local))

func _pin_world(j: int) -> Vector3:
	var p: Dictionary = pins[j]
	return _xf(p.bone, p.local)

func reset() -> void:
	pos.resize(rows * cols)
	prev.resize(rows * cols)
	var back := (_model_root.global_transform.basis * Vector3(0, 0, -1)).normalized() if _model_root else Vector3.BACK
	for j in cols:
		var top := _pin_world(j)
		for i in rows:
			var p := top + Vector3(0, -rest_v * i, 0) + back * 0.02 * i
			pos[i * cols + j] = p
			prev[i * cols + j] = p

func set_active(v: bool) -> void:
	_active = v
	visible = v

func _physics_process(delta: float) -> void:
	if not _active or skel == null or not _ready_done:
		return
	_t += delta
	_accum += delta
	# LOD: fora da tela não simula; longe da câmera simula com menos frequência e menos iterações
	var cam := get_viewport().get_camera_3d()
	var iters := stiff_iters
	if cam:
		var anchor := _pin_world(0)
		var dist := cam.global_position.distance_to(anchor)
		if dist > 3.0 and not cam.is_position_in_frustum(anchor) and not cam.is_position_in_frustum(anchor + Vector3(0, -_length, 0)):
			_accum = 0.0
			return
		var every := 1 if dist < 9.0 else (2 if dist < 18.0 else 4)
		_tick += 1
		if _tick % every != 0:
			return
		if dist > 6.0:
			iters = 2
	var dt := minf(_accum, 1.0 / 20.0)
	_accum = 0.0
	# pinos
	for j in cols:
		var w := _pin_world(j)
		if pos[j].distance_to(w) > 1.5:
			reset()
			break
		pos[j] = w
		prev[j] = w
	var wind := Vector3(sin(_t * 0.7) * 0.6 + 0.4, 0.0, cos(_t * 0.53) * 0.5) * wind_strength
	if Engine.has_singleton("Game") or true:
		var g = get_node_or_null("/root/Game")
		if g and g.get("wind") != null:
			wind += g.wind
	var acc := Vector3(0, -gravity, 0) + wind
	for k in range(cols, rows * cols):
		var p := pos[k]
		var v := (p - prev[k]) * damping
		prev[k] = p
		var flutter := sin(_t * 6.0 + float(k) * 0.7) * 0.15
		pos[k] = p + v + (acc + Vector3(flutter, 0, flutter * 0.5)) * dt * dt
	# colisores em mundo
	var cw := []
	for c in colliders:
		cw.append([_xf(c.bone, c.local), c.r])
	var floor_y := (_model_root.global_position.y if _model_root else 0.0) + 0.03
	for it in iters:
		for i in rows:
			for j in cols:
				var k := i * cols + j
				if j < cols - 1:
					_solve(k, k + 1, rest_h, i == 0)
				if i < rows - 1:
					_solve(k, k + cols, rest_v, i == 0)
				if i < rows - 2:
					_solve(k, k + cols * 2, rest_v * 2.0, i == 0, 0.5)
		for k in range(cols, rows * cols):
			var p := pos[k]
			for c in cw:
				var d: Vector3 = p - c[0]
				var l := d.length()
				if l < c[1] and l > 0.0001:
					p = c[0] + d / l * c[1]
			if p.y < floor_y:
				p.y = floor_y
			pos[k] = p
	_rebuild()

func _solve(a: int, b: int, rest: float, a_pinned: bool, k := 1.0) -> void:
	var d := pos[b] - pos[a]
	var l := d.length()
	if l < 0.00001:
		return
	var diff := (l - rest) / l * k
	if a_pinned:
		pos[b] -= d * diff
	else:
		pos[a] += d * diff * 0.5
		pos[b] -= d * diff * 0.5

func _sample(fi: float, fj: float) -> Vector3:
	var i0 := int(floor(fi)); var j0 := int(floor(fj))
	var i1 := min(i0 + 1, rows - 1); var j1 := min(j0 + 1, cols - 1)
	var ti := fi - i0; var tj := fj - j0
	var a := pos[i0 * cols + j0].lerp(pos[i0 * cols + j1], tj)
	var b := pos[i1 * cols + j0].lerp(pos[i1 * cols + j1], tj)
	return a.lerp(b, ti)

func _rebuild() -> void:
	var verts := PackedVector3Array()
	verts.resize(_rr * _rc)
	for i in _rr:
		for j in _rc:
			verts[i * _rc + j] = _sample(float(i) * 0.5, float(j) * 0.5)
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for i in _rr:
		for j in _rc:
			var l := verts[i * _rc + max(j - 1, 0)]
			var r := verts[i * _rc + min(j + 1, _rc - 1)]
			var u := verts[max(i - 1, 0) * _rc + j]
			var d := verts[min(i + 1, _rr - 1) * _rc + j]
			norms[i * _rc + j] = (r - l).cross(d - u).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mat := material_override
	_arr_mesh.clear_surfaces()
	_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
