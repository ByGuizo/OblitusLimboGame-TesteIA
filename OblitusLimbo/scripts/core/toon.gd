class_name Toon
## Converte materiais padrão (StandardMaterial3D dos kits) para os shaders cel-shaded do jogo,
## com cache para que cada material de origem gere um único ShaderMaterial.

const WORLD := preload("res://shaders/toon_world.gdshader")
const WORLD_CUT := preload("res://shaders/toon_world_cut.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

static var _cache := {}
static var _mesh_cache := {}
static var _outline_mat: ShaderMaterial

static func outline_mat(px := 1.7) -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE
		_outline_mat.set_shader_parameter("px", px)
	return _outline_mat

## Material padrão → ShaderMaterial toon. Outros tipos voltam sem alteração.
static func to_toon(m: Material, outline := false, key := 0.25) -> Material:
	if m == null or not (m is BaseMaterial3D):
		return m
	var key_id := "%d|%s|%.2f" % [m.get_instance_id(), outline, key]
	if _cache.has(key_id):
		return _cache[key_id]
	var b: BaseMaterial3D = m
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		_cache[key_id] = m
		return m
	var cut: bool = b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var s := ShaderMaterial.new()
	s.shader = WORLD_CUT if cut else WORLD
	s.resource_name = b.resource_name
	if b.albedo_texture:
		s.set_shader_parameter("albedo_tex", b.albedo_texture)
		s.set_shader_parameter("use_tex", true)
	s.set_shader_parameter("albedo_col", b.albedo_color)
	s.set_shader_parameter("uv_scale", b.uv1_scale)
	s.set_shader_parameter("uv_offset", b.uv1_offset)
	if cut:
		s.set_shader_parameter("alpha_cut", b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5)
	if b.emission_enabled:
		s.set_shader_parameter("emission_col", Vector3(b.emission.r, b.emission.g, b.emission.b) * b.emission_energy_multiplier)
		if b.emission_texture:
			s.set_shader_parameter("emission_tex", b.emission_texture)
			s.set_shader_parameter("use_emis_tex", true)
	s.set_shader_parameter("key_amt", key)
	if outline and not cut:
		s.next_pass = outline_mat()
	_cache[key_id] = s
	return s

## Cópia da malha com todos os materiais de superfície convertidos (cache por malha).
static func convert_mesh(mesh: Mesh, outline := false, key := 0.25) -> Mesh:
	if mesh == null:
		return mesh
	var k := "%d|%s|%.2f" % [mesh.get_instance_id(), outline, key]
	if _mesh_cache.has(k):
		return _mesh_cache[k]
	var changed := false
	var out: Mesh = mesh
	for si in mesh.get_surface_count():
		var m := mesh.surface_get_material(si)
		var nm := to_toon(m, outline, key)
		if nm != m:
			if not changed:
				out = mesh.duplicate()
				changed = true
			out.surface_set_material(si, nm)
	_mesh_cache[k] = out
	return out

## Converte uma árvore de nós (props instanciados, armas).
static func convert_tree(root: Node, outline := false, key := 0.25) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n
		if gi.material_override:
			gi.material_override = to_toon(gi.material_override, outline, key)
		if gi is MeshInstance3D:
			var mi: MeshInstance3D = gi
			if mi.mesh:
				for si in mi.mesh.get_surface_count():
					var cur := mi.get_surface_override_material(si)
					var src := cur if cur else mi.mesh.surface_get_material(si)
					var nm := to_toon(src, outline, key)
					if nm != src:
						mi.set_surface_override_material(si, nm)

## Quad de contorno em tela preso a uma câmera.
static func make_outline_quad(cam: Camera3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/outline_post.gdshader")
	m.render_priority = -100
	mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(mi)
	mi.position = Vector3(0, 0, -1.0)
	return mi
