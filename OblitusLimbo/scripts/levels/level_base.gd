class_name LevelBase
extends Node3D
## Base dos cenários: peças de kit agrupadas em MultiMesh, colisores simples, limites da
## arena, ambiente (céu, neblina volumétrica, brilho, SSAO) conforme a qualidade.

const SKY := preload("res://shaders/sky_night.gdshader")

var level_name := ""
var surface := "stone"
var bounds := {"type": "box", "min": Vector2(-10, -10), "max": Vector2(10, 10)}
var cam_extra := 2.0
var ceiling := 0.0
var points := {}
var spawn := {"pos": Vector3.ZERO, "yaw": 0.0}
var map_shapes: Array = []      # [{"type":"rect"/"circle", ...}] para o minimapa
var env: Environment
var sun: DirectionalLight3D
var flicker: Array = []         # luzes que tremulam [luz, energia_base, fase]
var anim_t := 0.0
var purple := 0.12              # tom violeta nas sombras (pós-processo)

var _batches := {}              # caminho -> Array[Transform3D]
var _batch_opts := {}           # caminho -> {cell, vis_end, shadow}
var _overrides := {}            # caminho -> Callable(mesh_instance) para trocar material
var _scene_cache := {}

func build() -> void:
	pass

func update(_delta: float) -> void:
	pass

func _process(delta: float) -> void:
	anim_t += delta
	for f in flicker:
		var l: Light3D = f[0]
		if is_instance_valid(l):
			l.light_energy = f[1] * (0.85 + sin(anim_t * 13.0 + f[2]) * 0.08 + sin(anim_t * 29.0 + f[2] * 2.0) * 0.06)
	if sun and Game.player and is_instance_valid(Game.player):
		pass
	update(delta)

# ---------------------------------------------------------------------
#  Peças
# ---------------------------------------------------------------------
## Caminhos podem ter um sufixo "#etiqueta" para formar lotes separados do mesmo modelo.
func scene(path: String) -> PackedScene:
	var p := path.get_slice("#", 0)
	if not _scene_cache.has(p):
		_scene_cache[p] = load(p)
	return _scene_cache[p]

static func kit(k: String, n: String) -> String:
	return "res://assets/%s/%s.gltf" % [k, n]

## Modo Versus: níveis montam uma arena de luta (ex.: plataforma maior no Limbo).
static var arena := false
static var skip: Array = []     # depuração: caminhos contendo estes termos não são criados

## Agenda uma peça para o lote (MultiMesh). rot em graus (Y).
func put(path: String, pos: Vector3, rot_y := 0.0, s := Vector3.ONE, extra_basis := Basis()) -> void:
	for k in skip:
		if path.contains(k):
			return
	if not _batches.has(path):
		_batches[path] = []
	var b := Basis(Vector3.UP, deg_to_rad(rot_y)) * extra_basis
	b = b.scaled_local(s) if s != Vector3.ONE else b
	_batches[path].append(Transform3D(b, pos))

func putk(k: String, n: String, pos: Vector3, rot_y := 0.0, sc = 1.0) -> void:
	var s: Vector3 = Vector3.ONE * sc if typeof(sc) != TYPE_VECTOR3 else sc
	put(kit(k, n), pos, rot_y, s)

## Instancia uma peça única (quando precisa de nó próprio, ex.: material diferente).
func inst(path: String, pos: Vector3, rot_y := 0.0, sc := 1.0) -> Node3D:
	var n: Node3D = scene(path).instantiate()
	add_child(n)
	Toon.convert_tree(n)
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y)
	n.scale = Vector3.ONE * sc
	return n

func override_material(path: String, fn: Callable) -> void:
	_overrides[path] = fn

## Opções de lote: tamanho da célula (culling por região), distância máxima de desenho e sombra.
func batch_opts(path: String, cell := 16.0, vis_end := 0.0, shadow := true) -> void:
	_batch_opts[path] = {"cell": cell, "vis_end": vis_end, "shadow": shadow}

## Cria os MultiMesh a partir dos lotes agendados. Lotes grandes são divididos em células
## para que o culling por frustum, o LOD automático e a distância de desenho funcionem.
func flush() -> void:
	for path in _batches:
		var all: Array = _batches[path]
		if all.is_empty():
			continue
		var o: Dictionary = _batch_opts.get(path, {})
		var cell: float = o.get("cell", 16.0)
		var groups := {}
		if all.size() > 12 and cell > 0.0:
			for xf in all:
				var k := Vector2i(floori(xf.origin.x / cell), floori(xf.origin.z / cell))
				if not groups.has(k):
					groups[k] = []
				groups[k].append(xf)
		else:
			groups[Vector2i.ZERO] = all
		var src: Node3D = scene(path).instantiate()
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			var local: Transform3D = Transform3D.IDENTITY
			var n: Node = mi
			while n and n != src:
				local = (n as Node3D).transform * local
				n = n.get_parent()
			for k in groups:
				var xfs: Array = groups[k]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mi.mesh
				mm.instance_count = xfs.size()
				for i in xfs.size():
					mm.set_instance_transform(i, xfs[i] * local)
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if o.get("shadow", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if o.get("vis_end", 0.0) > 0.0:
					mmi.visibility_range_end = o.vis_end
					mmi.visibility_range_end_margin = 4.0
				if _overrides.has(path):
					_overrides[path].call(mmi, mi)
				# estilo anime: materiais dos kits viram cel-shading
				if mmi.material_override:
					mmi.material_override = Toon.to_toon(mmi.material_override)
				mmi.multimesh.mesh = Toon.convert_mesh(mmi.multimesh.mesh)
				add_child(mmi)
		src.free()
	_batches.clear()

## Troca os materiais de uma peça do lote: fn(nome_material, material) -> Material
func recolor(path: String, fn: Callable) -> void:
	for tag in ["", "#far"]:
		_recolor_one(path + tag, fn)

func _recolor_one(path: String, fn: Callable) -> void:
	override_material(path, func(mmi: MultiMeshInstance3D, src: MeshInstance3D):
		var mesh_copy: Mesh = src.mesh.duplicate()
		for si in mesh_copy.get_surface_count():
			var m: Material = src.mesh.surface_get_material(si)
			var nm: Material = fn.call(m.resource_name if m else "", m)
			if nm:
				mesh_copy.surface_set_material(si, nm)
		mmi.multimesh.mesh = mesh_copy)

## Cópia de um StandardMaterial com a cor multiplicada (e emissão opcional).
static func tinted(m: Material, mul: Color, emit := Color.BLACK, emit_e := 1.0) -> Material:
	if not (m is BaseMaterial3D):
		return m
	var d: BaseMaterial3D = m.duplicate()
	d.albedo_color = d.albedo_color * mul
	if emit != Color.BLACK:
		d.emission_enabled = true
		d.emission = emit
		d.emission_energy_multiplier = emit_e
	return d

## Material simples (cor, rugosidade, metal)
static func mat(c: Color, rough := 0.85, metal := 0.0, emit := Color.BLACK, emit_e := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m

## Malha simples posicionada (com material) — atalho para adereços procedurais.
func prim(mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.to_toon(material)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = size; return b

static func cyl(r_top: float, r_bot: float, h: float, segs := 12) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h; c.radial_segments = segs; c.rings = 1
	return c

## Anel plano (UV.x ao redor, UV.y radial) para runas no chão.
static func ring_mesh(r0: float, r1: float, segs := 96, u_rep := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var u0 := float(i) / segs * u_rep
		var u1 := float(i + 1) / segs * u_rep
		var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a0) * r1, 0, sin(a0) * r1), Vector3(cos(a1) * r0, 0, sin(a1) * r0), Vector3(cos(a1) * r1, 0, sin(a1) * r1)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 0), Vector2(u1, 1)]
		for k in [0, 2, 1, 1, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	return st.commit()

## Material de runas emissivas.
static func rune_mat(col: Color, cells := Vector2(24, 3), reveal := 1.0, intensity := 2.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/runes.gdshader")
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("cells", cells)
	m.set_shader_parameter("reveal", reveal)
	m.set_shader_parameter("intensity", intensity)
	return m

## Chão grande com shader procedural.
func ground(size: float, mode: int, params := {}) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/floor.gdshader")
	m.set_shader_parameter("mode", mode)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return prim(pm, m, Vector3.ZERO, Vector3.ZERO, null, false)

## Espalha peças num anel (r0..r1) evitando um raio livre em torno de pontos.
func scatter(paths: Array, n: int, r0: float, r1: float, s0: float, s1: float, rng: RandomNumberGenerator, avoid: Array = [], center := Vector3.ZERO) -> Array:
	var placed := []
	var tries := 0
	while placed.size() < n and tries < n * 6:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(r0 * r0, r1 * r1))
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for av in avoid:
			if Vector2(p.x - av[0].x, p.z - av[0].z).length() < av[1]:
				ok = false; break
		if not ok:
			continue
		var sc := rng.randf_range(s0, s1)
		put(paths[rng.randi() % paths.size()], p, rng.randf() * 360.0, Vector3(sc, sc * rng.randf_range(0.85, 1.15), sc))
		placed.append(p)
	return placed

# ---------------------------------------------------------------------
#  Colisão
# ---------------------------------------------------------------------
var _static: StaticBody3D

func _body() -> StaticBody3D:
	if _static == null:
		_static = StaticBody3D.new()
		_static.collision_layer = 1
		_static.collision_mask = 0
		add_child(_static)
	return _static

func floor_collider(y := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var ws := WorldBoundaryShape3D.new()
	ws.plane = Plane(Vector3.UP, y)
	cs.shape = ws
	_body().add_child(cs)

func box_collider(center: Vector3, size: Vector3, rot_y := 0.0, show_on_map := true) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	cs.rotation.y = deg_to_rad(rot_y)
	_body().add_child(cs)
	if show_on_map:
		map_shapes.append({"type": "rect", "c": Vector2(center.x, center.z), "s": Vector2(size.x, size.z), "r": deg_to_rad(rot_y)})

func cyl_collider(center: Vector3, radius: float, height := 2.0, show_on_map := true) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position = center + Vector3(0, height * 0.5, 0)
	_body().add_child(cs)
	if show_on_map:
		map_shapes.append({"type": "circle", "c": Vector2(center.x, center.z), "r": radius})

## Paredes invisíveis nos limites da arena.
func bound_walls() -> void:
	if bounds.type == "box":
		var mn: Vector2 = bounds.min
		var mx: Vector2 = bounds.max
		var h := 12.0
		var cx := (mn.x + mx.x) * 0.5
		var cz := (mn.y + mx.y) * 0.5
		box_collider(Vector3(cx, h * 0.5, mn.y - 0.5), Vector3(mx.x - mn.x + 2, h, 1), 0, false)
		box_collider(Vector3(cx, h * 0.5, mx.y + 0.5), Vector3(mx.x - mn.x + 2, h, 1), 0, false)
		box_collider(Vector3(mn.x - 0.5, h * 0.5, cz), Vector3(1, h, mx.y - mn.y + 2), 0, false)
		box_collider(Vector3(mx.x + 0.5, h * 0.5, cz), Vector3(1, h, mx.y - mn.y + 2), 0, false)
	else:
		var r: float = bounds.r
		var c: Vector2 = bounds.get("c", Vector2.ZERO)
		var n := 32
		for i in n:
			var a := TAU * i / n
			var p := Vector3(c.x + cos(a) * (r + 0.5), 6.0, c.y + sin(a) * (r + 0.5))
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.0, 12.0, TAU * (r + 0.5) / n + 0.3)
			cs.shape = bs
			cs.position = p
			cs.rotation.y = -a
			_body().add_child(cs)

func outside(p: Vector3, margin := 0.0) -> bool:
	if bounds.type == "box":
		return p.x < bounds.min.x - margin or p.x > bounds.max.x + margin or p.z < bounds.min.y - margin or p.z > bounds.max.y + margin
	var c: Vector2 = bounds.get("c", Vector2.ZERO)
	return Vector2(p.x - c.x, p.z - c.y).length() > bounds.r + margin

func clamp_point(p: Vector3, r := 0.4) -> Vector3:
	if bounds.type == "box":
		return Vector3(clamp(p.x, bounds.min.x + r, bounds.max.x - r), p.y, clamp(p.z, bounds.min.y + r, bounds.max.y - r))
	var c: Vector2 = bounds.get("c", Vector2.ZERO)
	var d := Vector2(p.x - c.x, p.z - c.y)
	if d.length() > bounds.r - r:
		d = d.normalized() * (bounds.r - r)
	return Vector3(c.x + d.x, p.y, c.y + d.y)

func cam_clamp(p: Vector3) -> Vector3:
	var q := p
	if bounds.type == "box":
		q.x = clamp(q.x, bounds.min.x + 0.3, bounds.max.x - 0.3)
		q.z = clamp(q.z, bounds.min.y + 0.3, bounds.max.y - 0.3)
	else:
		var c: Vector2 = bounds.get("c", Vector2.ZERO)
		var d := Vector2(q.x - c.x, q.z - c.y)
		var m: float = bounds.r + cam_extra
		if d.length() > m:
			d = d.normalized() * m
		q.x = c.x + d.x; q.z = c.y + d.y
	if ceiling > 0.0:
		q.y = min(q.y, ceiling - 0.4)
	return q

# ---------------------------------------------------------------------
#  Ambiente
# ---------------------------------------------------------------------
## o: céu (top, horizon, bottom, moon_dir, stars, clouds, mode), neblina, luz ambiente, sol
func setup_env(o: Dictionary) -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY
	sm.set_shader_parameter("mode", o.get("sky_mode", 0))
	sm.set_shader_parameter("top_col", o.get("top", Color(0.01, 0.015, 0.05)))
	sm.set_shader_parameter("horizon_col", o.get("horizon", Color(0.07, 0.09, 0.2)))
	sm.set_shader_parameter("bottom_col", o.get("bottom", Color(0.01, 0.01, 0.02)))
	sm.set_shader_parameter("moon_dir", o.get("moon_dir", Vector3(-0.35, 0.55, 0.75)))
	sm.set_shader_parameter("star_amount", o.get("stars", 1.0))
	sm.set_shader_parameter("cloud_amount", o.get("clouds", 0.5))
	sm.set_shader_parameter("vein_amount", o.get("veins", 1.0))
	sm.set_shader_parameter("cloud_col", o.get("cloud_col", Color(0.1, 0.1, 0.22)))
	sm.set_shader_parameter("cloud_lit_col", o.get("cloud_lit", Color(0.5, 0.46, 0.82)))
	sm.set_shader_parameter("vein_col", o.get("vein_col", Color(0.75, 0.15, 0.95)))
	sm.set_shader_parameter("vein_base", o.get("vein_base", Color(0.07, 0.01, 0.12)))
	# iluminação anime global (personagens + cenário)
	purple = o.get("purple", 0.12)
	RenderingServer.global_shader_parameter_set("toon_shadow", o.get("toon_shadow", Color(0.56, 0.5, 0.78)))
	RenderingServer.global_shader_parameter_set("toon_key", o.get("toon_key", 0.3))
	RenderingServer.global_shader_parameter_set("toon_key_col", o.get("toon_key_col", Color(1.0, 0.96, 0.92)))
	RenderingServer.global_shader_parameter_set("toon_rim_col", o.get("toon_rim_col", Color(0.82, 0.78, 1.0)))
	RenderingServer.global_shader_parameter_set("toon_rim", o.get("toon_rim", 0.3))
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if o.get("sky_mode", 0) == 1 else Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY if not o.has("bg_color") else Environment.BG_COLOR
	env.background_color = o.get("bg_color", Color.BLACK)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = o.get("ambient", Color(0.3, 0.34, 0.5))
	env.ambient_light_energy = o.get("ambient_energy", 0.6)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = o.get("exposure", 1.0)
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = o.get("glow", 0.8)
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = o.get("glow_threshold", 1.0)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 0.0); env.set_glow_level(2, 1.0); env.set_glow_level(3, 1.0); env.set_glow_level(4, 0.6); env.set_glow_level(5, 0.3)
	if Save.opts.get("quality", "med") != "high":
		env.set_glow_level(2, 0.0); env.set_glow_level(3, 1.3); env.set_glow_level(5, 0.0)
	env.adjustment_enabled = true
	env.adjustment_contrast = o.get("contrast", 1.08)
	env.adjustment_saturation = o.get("saturation", 1.05)
	var fog_col: Color = o.get("fog", Color(0.05, 0.07, 0.15))
	env.fog_enabled = true
	env.fog_light_color = fog_col
	env.fog_density = o.get("fog_density", 0.01)
	env.fog_sky_affect = o.get("fog_sky", 0.4)
	env.fog_aerial_perspective = 0.3
	var q: String = Save.opts.get("quality", "med")
	if q != "low":
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = o.get("vol_density", 0.02)
		env.volumetric_fog_albedo = o.get("vol_albedo", fog_col.lightened(0.3))
		env.volumetric_fog_emission = o.get("vol_emission", Color.BLACK)
		env.volumetric_fog_length = 48.0 if q == "high" else 32.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_ambient_inject = o.get("vol_ambient", 0.3)
		env.volumetric_fog_gi_inject = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.fog_density = o.get("fog_density", 0.01) * 0.5
		env.ssao_enabled = q == "high"
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.6
		env.ssao_power = 1.4
		if q == "med":
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
			RenderingServer.environment_set_volumetric_fog_volume_size(48, 48)
		else:
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50.0, 300.0)
			RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
	if q == "high":
		env.ssil_enabled = true
		env.ssil_intensity = 0.8
		env.ssr_enabled = o.get("ssr", false)
		env.ssr_max_steps = 48
	we.environment = env
	add_child(we)
	# lua / sol
	sun = DirectionalLight3D.new()
	sun.light_color = o.get("sun_col", Color(0.62, 0.7, 1.0))
	sun.light_energy = o.get("sun", 0.6)
	sun.rotation_degrees = o.get("sun_rot", Vector3(-50, -150, 0))
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 50.0 if q == "high" else (34.0 if q == "med" else 24.0)
	sun.shadow_blur = 1.5
	sun.light_volumetric_fog_energy = o.get("sun_fog", 1.0)
	add_child(sun)

func omni(pos: Vector3, col: Color, energy: float, rng: float, shadows := false, flick := false, fog := 1.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows and Save.opts.get("quality", "med") != "low"
	l.light_volumetric_fog_energy = fog
	add_child(l)
	if flick:
		flicker.append([l, energy, randf() * 10.0])
	return l

## Partículas ambientes contínuas numa caixa (brasas, poeira, pétalas, vaga-lumes).
func ambient_particles(kind: String, center: Vector3, extents: Vector3, rate: float, o := {}) -> void:
	var oo := {"n": 1, "r": 0.0}
	oo.merge(o, true)
	set_meta("amb_%s" % kind, [center, extents, rate, 0.0, oo])

func _physics_process(delta: float) -> void:
	if Game.fx == null:
		return
	for m in get_meta_list():
		if not m.begins_with("amb_"):
			continue
		var a: Array = get_meta(m)
		a[3] += delta * a[2]
		while a[3] >= 1.0:
			a[3] -= 1.0
			var c: Vector3 = a[0]
			var e: Vector3 = a[1]
			var p := c + Vector3(randf_range(-e.x, e.x), randf_range(-e.y, e.y), randf_range(-e.z, e.z))
			Game.fx.burst(m.substr(4), p, a[4])

func free_level() -> void:
	queue_free()
