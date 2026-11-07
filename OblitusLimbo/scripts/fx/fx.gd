class_name FX
extends Node3D
## Efeitos visuais (porte de fx.js) com partículas na GPU emitidas manualmente.

const P_SHADER := preload("res://shaders/fx_particles.gdshader")
const D_ADD := preload("res://shaders/fx_draw.gdshader")
const D_MIX := preload("res://shaders/fx_draw_mix.gdshader")
const SHAPES := preload("res://shaders/fx_shapes.gdshader")

# tipo: [desenho, textura, gravidade, arrasto, tamanho_final, giro, turbulência, multiplicador_final, intensidade, capacidade]
const TYPES := {
	"spark": ["add", "vfx:spark_star", 14.0, 2.0, 0.1, 3.0, 0.0, Vector3(1.0, 0.45, 0.1), 3.0, 1500],
	"fire": ["add", "vfx:flame", -1.0, 1.5, 0.6, 0.3, 1.0, Vector3(1.0, 0.3, 0.05), 2.0, 2500],
	"magic": ["add", "glow", -0.5, 2.0, 0.1, 0.0, 0.5, Vector3(0.4, 0.9, 1.1), 2.6, 2000],
	"ice": ["mix", "vfx:ice_shard", 10.0, 1.5, 0.3, 4.0, 0.0, Vector3(0.6, 0.8, 1.0), 1.0, 800],
	"heal": ["add", "glow", -0.3, 0.5, 0.1, 0.0, 0.0, Vector3(0.3, 0.6, 0.3), 2.0, 400],
	"gold": ["add", "glow", -0.2, 0.5, 0.1, 0.0, 0.3, Vector3(1.0, 0.6, 0.15), 2.5, 600],
	"ember": ["add", "vfx:spark_star", -0.05, 0.1, 0.2, 1.0, 0.6, Vector3(1.0, 0.2, 0.0), 3.0, 600],
	"mote": ["add", "glow", 0.0, 0.0, 0.2, 0.0, 0.4, Vector3(0.5, 0.5, 0.7), 1.4, 600],
	"water": ["add", "glow", 12.0, 0.5, 0.2, 0.0, 0.0, Vector3(0.3, 0.5, 0.9), 1.6, 1200],
	"blood": ["mix", "glow", 12.0, 1.0, 0.4, 0.0, 0.0, Vector3(0.45, 0.2, 0.2), 1.0, 800],
	"smoke": ["mix", "vfx:toon_smoke", -0.2, 0.6, 2.0, 0.4, 0.6, Vector3(0.8, 0.8, 0.85), 1.0, 800],
	"dust": ["mix", "vfx:toon_smoke", 0.5, 2.5, 2.2, 0.4, 0.3, Vector3(0.8, 0.78, 0.75), 1.0, 600],
	"shadow": ["mix", "vfx:toon_smoke", -0.4, 1.2, 1.7, 0.8, 0.8, Vector3(0.5, 0.4, 0.6), 1.0, 2000],
	"wind": ["mix", "vfx:toon_smoke", -0.5, 1.0, 1.6, 2.0, 0.5, Vector3(0.9, 0.92, 0.95), 1.0, 800],
	"note": ["add", "vfx:note", -0.6, 0.8, 0.6, 0.8, 0.6, Vector3(1.0, 0.9, 1.0), 2.2, 300],
	"star": ["add", "vfx:spark_star6", 0.0, 3.0, 0.2, 2.0, 0.0, Vector3(1.0, 0.6, 0.3), 3.5, 400],
	"petal": ["mix", "petal", 0.05, 0.1, 0.8, 3.0, 1.2, Vector3(0.5, 0.2, 0.2), 1.0, 500],
}

var systems := {}
var _tex := {}
var lights: Array[OmniLight3D] = []
var items: Array = []          # efeitos temporários com atualização
var hazard_nodes: Array = []

func _ready() -> void:
	for t in TYPES:
		_make_system(t)
	for i in 4:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 8.0
		l.shadow_enabled = false
		add_child(l)
		l.set_meta("t", 0.0)
		lights.append(l)

# ---------------------------------------------------------------------
#  Texturas procedurais
# ---------------------------------------------------------------------
const FLIP := {"vfx:toon_smoke": 4, "vfx:flame": 4}

func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	if n.begins_with("vfx:"):
		_tex[n] = load("res://assets/vfx/%s.png" % n.substr(4))
		return _tex[n]
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := (x + 0.5) / s * 2.0 - 1.0
			var dy := (y + 0.5) / s * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var a := 0.0
			match n:
				"glow":
					a = pow(clamp(1.0 - r, 0.0, 1.0), 1.8)
				"spark":
					a = pow(clamp(1.0 - r, 0.0, 1.0), 3.0) + max(0.0, 1.0 - abs(dx) * 14.0) * max(0.0, 1.0 - abs(dy)) * 0.5 + max(0.0, 1.0 - abs(dy) * 14.0) * max(0.0, 1.0 - abs(dx)) * 0.5
				"smoke":
					var nn := 0.6 + 0.4 * sin(x * 0.4 + sin(y * 0.3) * 2.0) * cos(y * 0.35 + x * 0.1)
					a = clamp(1.0 - r, 0.0, 1.0) * nn * 1.3
				"petal":
					a = 1.0 if (dx * dx * 2.5 + dy * dy) < 0.6 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, clamp(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_tex[n] = ImageTexture.create_from_image(img)
	return _tex[n]

func _make_system(t: String) -> void:
	var c: Array = TYPES[t]
	var p := GPUParticles3D.new()
	p.amount = c[9]
	p.lifetime = 8.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 400, 1000))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ShaderMaterial.new()
	pm.shader = P_SHADER
	pm.set_shader_parameter("gravity", c[2])
	pm.set_shader_parameter("drag", c[3])
	pm.set_shader_parameter("size_end", c[4])
	pm.set_shader_parameter("spin", c[5])
	pm.set_shader_parameter("turbulence", c[6])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var dm := ShaderMaterial.new()
	dm.shader = D_ADD if c[0] == "add" else D_MIX
	dm.set_shader_parameter("tex", tex(c[1]))
	dm.set_shader_parameter("flip", FLIP.get(c[1], 1))
	dm.set_shader_parameter("end_mul", c[7])
	if c[0] == "add":
		dm.set_shader_parameter("intensity", c[8])
	q.material = dm
	p.draw_pass_1 = q
	add_child(p)
	systems[t] = p

const FLAGS := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM

func emit(t: String, pos: Vector3, vel: Vector3, life: float, size: float, col: Color) -> void:
	var p: GPUParticles3D = systems[t]
	p.emit_particle(Transform3D(Basis(), pos), vel, col, Color(life, 0.0, size, randf() * TAU), FLAGS)

static func _rv() -> Vector3:
	return Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()

## Rajadas com a mesma semântica do fx.js
func burst(t: String, p: Vector3, o := {}) -> void:
	var n: int = o.get("n", 12)
	var dir: Vector3 = o.get("dir", Vector3.ZERO)
	var col: Color = o.get("color", Color(-1, 0, 0))
	var sz: float = o.get("size", 1.0)
	var r: float = o.get("r", 0.25)
	var sp: float = o.get("speed", 1.0)
	for i in n:
		match t:
			"spark":
				var v := _rv() * randf_range(3, 9) + dir * 5.0 + Vector3(0, 2, 0)
				emit("spark", p, v, randf_range(0.2, 0.5), randf_range(0.06, 0.14), col if col.r >= 0 else Color(1, 0.95, 0.75))
			"blood":
				var v := _rv() * randf_range(1.5, 4.5) + dir * 3.0 + Vector3(0, 2, 0)
				emit("blood", p, v, randf_range(0.4, 0.8), randf_range(0.07, 0.14), Color(0.45, 0.0, 0.03, 0.95))
			"fire":
				var q := p + Vector3(randf_range(-1, 1) * r, randf_range(0, 0.2), randf_range(-1, 1) * r)
				emit("fire", q, Vector3(randf_range(-0.4, 0.4), randf_range(1.5, 3.5) * o.get("up", 1.0), randf_range(-0.4, 0.4)), randf_range(0.4, 0.9), randf_range(0.28, 0.55) * sz, col if col.r >= 0 else Color(1, 0.8, 0.35))
			"smoke":
				var q := p + Vector3(randf_range(-1, 1) * r, 0, randf_range(-1, 1) * r)
				emit("smoke", q, Vector3(randf_range(-0.5, 0.5), randf_range(0.4, 1.4), randf_range(-0.5, 0.5)), randf_range(1.0, 2.0), randf_range(0.5, 0.9) * sz, (col if col.r >= 0 else Color(0.16, 0.16, 0.19)) * Color(1, 1, 1, o.get("alpha", 0.55)))
			"dust":
				var v := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1, 4) * sp
				v.y = randf_range(0.2, 1.2)
				emit("dust", p, v, randf_range(0.6, 1.2), randf_range(0.35, 0.6) * sz, Color(0.42, 0.36, 0.3, 0.5))
			"magic":
				var v := _rv() * randf_range(0.5, 3.0) * sp + dir * 3.0
				emit("magic", p, v, randf_range(0.4, 0.9), randf_range(0.12, 0.3) * sz, col if col.r >= 0 else Color(0.7, 0.45, 1.0))
			"ice":
				var v := _rv() * randf_range(2, 6) * sp + Vector3(0, 1.5, 0)
				emit("ice", p, v, randf_range(0.3, 0.7), randf_range(0.07, 0.15), Color(1, 1, 1))
				if i % 2 == 1:
					emit("magic", p, v * 0.4, randf_range(0.4, 0.8), randf_range(0.2, 0.4), Color(0.6, 0.9, 1.0))
			"shadow":
				var v := _rv() * randf_range(0.3, 1.5) * sp
				v.y = abs(v.y) + 0.5
				emit("shadow", p + _rv() * r, v, randf_range(0.6, 1.4), randf_range(0.3, 0.6) * sz, (col if col.r >= 0 else Color(0.03, 0.015, 0.05)) * Color(1, 1, 1, 0.85))
			"heal":
				emit("heal", p + Vector3(randf_range(-0.4, 0.4), randf_range(0, 1.6), randf_range(-0.4, 0.4)), Vector3(0, randf_range(0.6, 1.6), 0), randf_range(0.6, 1.2), randf_range(0.1, 0.2), Color(0.5, 1.0, 0.56))
			"water":
				var v := _rv() * randf_range(2, 6)
				v.y = abs(v.y) * 2.0 + 2.0
				emit("water", p, v, randf_range(0.4, 0.9), randf_range(0.1, 0.22), Color(0.66, 0.88, 1.0))
			"wind":
				var a := randf() * TAU
				var rr := randf_range(0.5, o.get("r", 2.5))
				var q := Vector3(p.x + cos(a) * rr, p.y + randf_range(0, o.get("h", 3.0)), p.z + sin(a) * rr)
				emit("wind", q, Vector3(-sin(a), 0.4, cos(a)) * randf_range(4, 8), randf_range(0.4, 0.8), randf_range(0.2, 0.4), Color(0.8, 0.86, 0.92, 0.35))
			"gold":
				emit("gold", p + _rv() * o.get("r", 0.5), Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.0), randf_range(-0.3, 0.3)), randf_range(0.8, 1.6), randf_range(0.08, 0.18) * sz, col if col.r >= 0 else Color(1, 0.82, 0.44))
			"petal":
				var q := p + Vector3(randf_range(-1, 1) * o.get("r", 6.0), randf_range(0, 3), randf_range(-1, 1) * o.get("r", 6.0))
				emit("petal", q, Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.1), randf_range(-0.6, 0.6)), randf_range(3, 6), 0.09, Color(0.6, 0.04, 0.1, 0.95))
			"ember":
				var q := p + Vector3(randf_range(-1, 1) * o.get("r", 6.0), randf_range(0, 0.5), randf_range(-1, 1) * o.get("r", 6.0))
				emit("ember", q, Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.0), randf_range(-0.3, 0.3)), randf_range(2, 4), randf_range(0.03, 0.06), col if col.r >= 0 else Color(1, 0.62, 0.25))
			"mote":
				var q := p + Vector3(randf_range(-1, 1) * o.get("r", 8.0), randf_range(0, 4), randf_range(-1, 1) * o.get("r", 8.0))
				emit("mote", q, Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2)), randf_range(3, 6), randf_range(0.05, 0.12), col if col.r >= 0 else Color(0.5, 0.56, 1.0))

func breath_puff(mouth: Vector3, yaw: float, blue: bool) -> void:
	for k in 4:
		var d := Game.fwd(yaw + randf_range(-0.42, 0.42)) * randf_range(8, 13)
		d.y = randf_range(-1.2, 0.1)
		emit("fire", mouth, d, randf_range(0.45, 0.75), randf_range(0.25, 0.5), Color(0.6, 0.78, 1.0) if blue else Color(1, 0.62, 0.25))
	emit("smoke", mouth, Game.fwd(yaw) * 6.0, 0.9, 0.4, Color(0.15, 0.12, 0.12, 0.35))

# ---------------------------------------------------------------------
#  Itens temporários
# ---------------------------------------------------------------------
## update(t, dt) chamado por quadro durante 'life' segundos; on_end ao final.
func custom(life: float, update: Callable, on_end := Callable()) -> Dictionary:
	var it := {"t": 0.0, "life": life, "update": update, "end": on_end, "kill": false}
	items.append(it)
	return it

func _process(delta: float) -> void:
	for it in items.duplicate():
		it.t += delta
		if it.t >= it.life or it.kill:
			items.erase(it)
			if it.end.is_valid():
				it.end.call()
			continue
		if it.update.is_valid():
			it.update.call(it.t, delta)
	for l in lights:
		var t: float = l.get_meta("t")
		if t > 0.0:
			t -= delta
			l.set_meta("t", t)
			l.light_energy = l.get_meta("e") * max(0.0, t / l.get_meta("d"))
		else:
			l.light_energy = 0.0
	# partículas das zonas de perigo
	for h in hazard_nodes.duplicate():
		if not is_instance_valid(h):
			hazard_nodes.erase(h)
			continue
		var kind: String = h.get_meta("kind")
		var rad: float = h.get_meta("radius")
		var fade: float = h.get_meta("fade", 1.0)
		var m: ShaderMaterial = h.get_meta("mat")
		m.set_shader_parameter("alpha", 0.6 * fade)
		if randf() < delta * 30.0 * rad:
			var q: Vector3 = h.global_position + Vector3(randf_range(-1, 1) * rad * 0.8, 0, randf_range(-1, 1) * rad * 0.8)
			match kind:
				"fire": burst("fire", q, {"n": 1, "r": 0.1})
				"blueflame": burst("fire", q, {"n": 1, "r": 0.1, "color": Color(0.6, 0.78, 1.0)})
				"wind": burst("wind", h.global_position, {"n": 2, "r": rad, "h": 4.0})
				"water": burst("water", q, {"n": 1})
				"shadow": burst("shadow", q, {"n": 1})

func _shape_mesh(mode: int, col: Color, size: Vector2) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = size
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = SHAPES
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("color", col)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

## Corte luminoso em arco diante do personagem.
var _arc_mesh: ArrayMesh
var _arc_big: ArrayMesh
func _arc(r0: float, r1: float, theta: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 24
	for i in seg:
		for k in [[i, 0], [i + 1, 0], [i, 1], [i + 1, 0], [i + 1, 1], [i, 1]]:
			var t := float(k[0]) / seg
			var a := -theta / 2.0 + theta * t
			var r := r1 if k[1] == 1 else r0
			st.set_uv(Vector2(t, k[1]))
			st.add_vertex(Vector3(sin(a) * r, 0, cos(a) * r))
	return st.commit()

func slash(pos: Vector3, yaw: float, o := {}) -> void:
	if _arc_mesh == null:
		_arc_mesh = _arc(0.55, 1.45, 2.6)
		_arc_big = _arc(0.8, 2.6, 3.2)
	var m := MeshInstance3D.new()
	m.mesh = _arc_big if o.get("big", false) else _arc_mesh
	var mat := ShaderMaterial.new()
	mat.shader = SHAPES
	mat.set_shader_parameter("mode", 4)
	var col: Color = o.get("color", Color(0.75, 0.9, 1.0))
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("intensity", o.get("intensity", 2.2))
	mat.set_shader_parameter("seed", randf() * 100.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	var s: float = o.get("scale", 1.0)
	var flip := -1.0 if o.get("flip", false) else 1.0
	m.rotation = Vector3(o.get("pitch", 0.0), yaw, 0)
	m.rotation_order = EULER_ORDER_YXZ
	m.rotation = Vector3(o.get("pitch", 0.0), yaw, o.get("roll", 0.0))
	m.scale = Vector3(s * flip, s, s)
	var dark: MeshInstance3D = null
	if o.get("dark", false):
		dark = MeshInstance3D.new()
		dark.mesh = m.mesh
		var dm := ShaderMaterial.new()
		dm.shader = D_MIX
		dark.material_override = _dark_arc_mat()
		add_child(dark)
		dark.global_transform = m.global_transform
		dark.scale = m.scale * 1.06
	var life: float = o.get("life", 0.22)
	var sweep: float = o.get("sweep", 0.9)
	custom(life, func(t, _dt):
		var f: float = t / life
		mat.set_shader_parameter("alpha", max(0.0, 1.0 - f * f))
		m.rotation.y = yaw - flip * sweep * (f - 0.5) * 0.6
		var ss: float = s * (1.0 + f * 0.15)
		m.scale = Vector3(ss * flip, ss, ss)
		if dark:
			dark.rotation = m.rotation
			(dark.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - f),
		func():
			m.queue_free()
			if dark: dark.queue_free())

var _dark_mat_proto: StandardMaterial3D
func _dark_arc_mat() -> StandardMaterial3D:
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0, 0, 0, 0.6)
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	return dm

func ring(pos: Vector3, o := {}) -> void:
	var m := _shape_mesh(3, o.get("color", Color(1, 0.82, 0.5)), Vector2(2, 2))
	(m.material_override as ShaderMaterial).set_shader_parameter("intensity", o.get("intensity", 2.0))
	add_child(m)
	m.global_position = pos + Vector3(0, 0.06, 0)
	var life: float = o.get("life", 0.5)
	var r0: float = o.get("r0", 0.2)
	var r1: float = o.get("r1", 4.0)
	custom(life, func(t, _dt):
		var f: float = t / life
		var e := 1.0 - pow(1.0 - f, 3.0)
		var r := r0 + (r1 - r0) * e
		m.scale = Vector3(r, 1, r)
		(m.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0 - f),
		func(): m.queue_free())

func sphere(pos: Vector3, o := {}) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var c: Color = o.get("color", Color(1, 1, 1))
	mat.albedo_color = c * o.get("intensity", 2.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	var life: float = o.get("life", 0.4)
	var r0: float = o.get("r0", 0.2)
	var r1: float = o.get("r1", 2.0)
	var op: float = o.get("opacity", 0.8)
	custom(life, func(t, _dt):
		var f: float = t / life
		m.scale = Vector3.ONE * (r0 + (r1 - r0) * (1.0 - pow(1.0 - f, 2.0)))
		mat.albedo_color.a = (1.0 - f) * op,
		func(): m.queue_free())

func flash(pos: Vector3, col := Color.WHITE, energy := 6.0, dur := 0.15, rng := 8.0) -> void:
	var best: OmniLight3D = lights[0]
	for l in lights:
		if l.get_meta("t") <= 0.0:
			best = l
			break
	best.global_position = pos
	best.light_color = col
	best.omni_range = rng
	best.set_meta("t", dur)
	best.set_meta("d", dur)
	best.set_meta("e", energy * 0.4)
	best.light_energy = energy * 0.4

## Aviso no chão. s: {shape, pos, radius, angle, yaw, width, length, inner}
func telegraph(s: Dictionary, time: float, col := Color(1, 0.16, 0.12)) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(s.pos.x, s.pos.y + 0.045, s.pos.z)
	root.rotation.y = s.get("yaw", 0.0)
	var m: MeshInstance3D
	match s.get("shape", "circle"):
		"circle":
			m = _shape_mesh(0, col, Vector2(s.radius * 2.0, s.radius * 2.0))
			(m.material_override as ShaderMaterial).set_shader_parameter("inner", s.get("inner", 0.0) / s.radius)
		"cone":
			m = _shape_mesh(1, col, Vector2(s.radius * 2.0, s.radius * 2.0))
			(m.material_override as ShaderMaterial).set_shader_parameter("angle", s.angle)
		"rect":
			m = _shape_mesh(2, col, Vector2(s.width, s.length))
			m.position = Vector3(0, 0, s.length * 0.5)
	root.add_child(m)
	var mat: ShaderMaterial = m.material_override
	custom(time + 0.05, func(t, _dt):
		if is_instance_valid(mat):
			mat.set_shader_parameter("fill", min(1.0, t / max(time, 0.01))))
	# weakref: o telegrafo pode ser removido antes (golpe cancelado / chefe limpa pendências)
	var wr := weakref(root)
	get_tree().create_timer(time + 2.0, false).timeout.connect(func():
		var r = wr.get_ref()
		if r: r.queue_free())
	return root

func hazard_visual(kind: String, radius: float) -> Node3D:
	var col := Color(1, 0.35, 0.06)
	match kind:
		"blueflame": col = Color(0.23, 0.5, 1.0)
		"wind": col = Color(0.75, 0.85, 0.95)
		"water": col = Color(0.25, 0.6, 1.0)
		"shadow": col = Color(0.4, 0.1, 0.5)
	var m := _shape_mesh(5, col, Vector2(radius * 2.0, radius * 2.0))
	m.set_meta("kind", kind)
	m.set_meta("radius", radius)
	m.set_meta("mat", m.material_override)
	m.set_meta("fade", 0.0)
	hazard_nodes.append(m)
	return m

func glow_ball(col: Color, r: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	m.material_override = mat
	return m

func projectile_visual(kind: String, o: Dictionary) -> Node3D:
	var root := Node3D.new()
	var c1: Color = o.get("color", Color(1, 1, 1))
	var sc: float = o.get("scale", 1.0)
	match kind:
		"crescent":
			for k in 2:
				var m := MeshInstance3D.new()
				m.mesh = _crescent_mesh()
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.albedo_color = (c1 if k == 0 else o.get("color2", Color(1, 0.82, 0.48))) * 3.0
				m.material_override = mat
				if k == 1:
					m.rotation.z = PI / 2.0
					m.scale = Vector3.ONE * 0.8
				root.add_child(m)
			root.scale = Vector3.ONE * sc
		"bolt", "arrow":
			var m := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.015; cm.bottom_radius = 0.015; cm.height = 0.6
			m.mesh = cm
			m.rotation.x = -PI / 2.0
			var mat := StandardMaterial3D.new()
			if o.get("glow", false):
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = c1 * 3.0
			else:
				mat.albedo_color = Color(0.82, 0.76, 0.62)
			m.material_override = mat
			root.add_child(m)
		"spear":
			var m := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.13; cm.height = 1.4; cm.radial_segments = 6
			m.mesh = cm
			m.rotation.x = -PI / 2.0
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.94, 1.0)
			mat.emission_enabled = true; mat.emission = Color(0.25, 0.6, 0.85); mat.emission_energy_multiplier = 1.5
			mat.roughness = 0.1
			m.material_override = mat
			root.add_child(m)
			root.scale = Vector3.ONE * sc
		"knife":
			# adaga de arremesso girando
			var m := MeshInstance3D.new()
			var bm := PrismMesh.new(); bm.size = Vector3(0.06, 0.32, 0.015)
			m.mesh = bm
			m.rotation.x = -PI / 2.0
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.82, 0.85, 0.92); mat.metallic = 0.8; mat.roughness = 0.2
			mat.emission_enabled = true; mat.emission = c1; mat.emission_energy_multiplier = 1.2
			m.material_override = mat
			root.add_child(m)
			root.set_meta("spin", 18.0)
			root.scale = Vector3.ONE * sc
		"needle":
			var m := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.018; cm.height = 0.5; cm.radial_segments = 4
			m.mesh = cm
			m.rotation.x = -PI / 2.0
			var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = c1 * 2.4 if o.has("color") else Color(2.4, 0.15, 0.25)
			m.material_override = mat
			root.add_child(m)
			root.scale = Vector3.ONE * sc
		"bottle":
			var m := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.07; cm.height = 0.24; cm.radial_segments = 8
			m.mesh = cm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.45, 0.25, 0.1, 0.85); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true; mat.emission = Color(1.0, 0.45, 0.1); mat.emission_energy_multiplier = 0.8
			m.material_override = mat
			root.add_child(m)
			root.set_meta("spin", 9.0)
		"wolf":
			# lobo espiritual: corpo alongado + cabeça + orelhas, verde translúcido e brilhante
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.12, 0.85, 0.35, 0.6)
			for part in [[Vector3(0, 0.45, 0), Vector3(0.22, 0.2, 0.5)], [Vector3(0, 0.62, -0.42), Vector3(0.15, 0.14, 0.2)], [Vector3(0, 0.6, -0.58), Vector3(0.08, 0.07, 0.14)],
					[Vector3(-0.06, 0.76, -0.4), Vector3(0.03, 0.08, 0.03)], [Vector3(0.06, 0.76, -0.4), Vector3(0.03, 0.08, 0.03)], [Vector3(0, 0.5, 0.4), Vector3(0.05, 0.05, 0.3)]]:
				var m := MeshInstance3D.new()
				var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 10; sm.rings = 6
				m.mesh = sm
				m.material_override = mat
				m.position = part[0]
				m.scale = part[1]
				root.add_child(m)
			var l := OmniLight3D.new(); l.light_color = Color(0.3, 1.0, 0.5); l.light_energy = 1.2; l.omni_range = 3.0
			l.position = Vector3(0, 0.6, 0)
			root.add_child(l)
			root.set_meta("ground", true)
			root.scale = Vector3.ONE * sc
		"crystal":
			var m := MeshInstance3D.new()
			var pm := PrismMesh.new(); pm.size = Vector3(0.16, 0.3, 0.1)
			m.mesh = pm
			var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1, 0.1, 0.2); mat.emission_enabled = true; mat.emission = Color(1, 0.05, 0.15); mat.emission_energy_multiplier = 4.0
			m.material_override = mat
			root.add_child(m)
			var l := OmniLight3D.new(); l.light_color = Color(1, 0.1, 0.2); l.light_energy = 2.0; l.omni_range = 3.0
			root.add_child(l)
			root.set_meta("spin", 6.0)
		"xslash":
			# Corte em X: dois crescentes cruzados (aço, sem fogo)
			for k in 2:
				var m := MeshInstance3D.new()
				m.mesh = _crescent_mesh()
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.albedo_color = c1 * 2.6
				m.material_override = mat
				m.rotation.z = PI * 0.25 if k == 0 else -PI * 0.25
				root.add_child(m)
			root.scale = Vector3.ONE * sc
		_:
			var m := glow_ball(c1 * 2.5, 0.18)
			root.add_child(m)
			var l := OmniLight3D.new(); l.light_color = c1; l.light_energy = 1.5; l.omni_range = 3.0
			root.add_child(l)
			root.scale = Vector3.ONE * sc
	return root

var _cres: ArrayMesh
func _crescent_mesh() -> ArrayMesh:
	if _cres:
		return _cres
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var a0 := lerp(-1.2, 1.2, float(i) / n)
		var a1 := lerp(-1.2, 1.2, float(i + 1) / n)
		var o0 := Vector3(0, sin(a0) * 0.7, cos(a0) * 0.7)
		var o1 := Vector3(0, sin(a1) * 0.7, cos(a1) * 0.7)
		var w0 := 0.22 * cos(a0 * 1.3)
		var w1 := 0.22 * cos(a1 * 1.3)
		var i0 := Vector3(0, sin(a0) * (0.7 - w0), cos(a0) * (0.7 - w0) - 0.05)
		var i1 := Vector3(0, sin(a1) * (0.7 - w1), cos(a1) * (0.7 - w1) - 0.05)
		for v in [o0, i0, o1, o1, i0, i1]:
			st.add_vertex(Vector3(v.y, 0, -(v.z - 0.45)))
	_cres = st.commit()
	return _cres

func ice_spike(pos: Vector3, o := {}) -> void:
	var h: float = o.get("h", randf_range(1.2, 2.2))
	var r: float = o.get("r", randf_range(0.18, 0.32))
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 5; cm.rings = 1
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	var black: bool = o.get("black", false)
	mat.albedo_color = Color(0.04, 0.1, 0.16, 0.92) if black else Color(0.75, 0.92, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.12, 0.25) if black else Color(0.16, 0.48, 0.7)
	mat.roughness = 0.08
	mat.metallic_specular = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	add_child(m)
	var base := Vector3(pos.x, pos.y - h * 0.5, pos.z)
	m.global_position = base
	m.rotation = Vector3(randf_range(-0.25, 0.25), randf() * 6.0, randf_range(-0.25, 0.25))
	var life: float = o.get("life", 1.6)
	custom(life, func(t, _dt):
		m.global_position.y = base.y + h * min(1.0, t / 0.12)
		if t > life - 0.3:
			mat.albedo_color.a = max(0.0, (life - t) / 0.3) * 0.9
			m.scale = Vector3.ONE * (1.0 + (t - life + 0.3)),
		func():
			if not o.get("silent", false):
				burst("ice", m.global_position + Vector3(0, h * 0.2, 0), {"n": 6})
			m.queue_free())

func laser() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.008; cm.bottom_radius = 0.008; cm.height = 1.0; cm.radial_segments = 4
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(3.0, 0.3, 0.15, 0.6)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func place_beam(m: MeshInstance3D, a: Vector3, b: Vector3, opacity := 1.0) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD if abs(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	m.global_transform = Transform3D(Basis(x, y * len, z), (a + b) * 0.5)
	(m.material_override as StandardMaterial3D).albedo_color.a = clamp(opacity, 0.0, 1.0)

func beam(a: Vector3, b: Vector3, o := {}) -> void:
	var m := laser()
	var mat: StandardMaterial3D = m.material_override
	mat.albedo_color = o.get("color", Color(1, 0.2, 0.3)) * 3.0
	(m.mesh as CylinderMesh).top_radius = o.get("width", 0.05)
	(m.mesh as CylinderMesh).bottom_radius = o.get("width", 0.05)
	add_child(m)
	place_beam(m, a, b, 1.0)
	var life: float = o.get("life", 0.25)
	custom(life, func(t, _dt): mat.albedo_color.a = 1.0 - t / life, func(): m.queue_free())

func meteor(p: Vector3, time: float) -> void:
	var m := glow_ball(Color(3, 1.2, 0.4), 0.4)
	add_child(m)
	m.global_position = p + Vector3(0, 14, 0)
	custom(time, func(t, _dt):
		m.global_position.y = p.y + 14.0 * (1.0 - t / time)
		burst("fire", m.global_position, {"n": 2, "size": 1.2, "r": 0.1}),
		func(): m.queue_free())

func clear() -> void:
	# ao trocar de nível os callbacks de fim não são chamados (os nós já foram descartados)
	items = []
	for c in get_children():
		if c is MeshInstance3D or (c is Node3D and not (c is GPUParticles3D) and not (c is OmniLight3D)):
			c.queue_free()
	for p in systems.values():
		p.restart()
		p.emitting = false
	hazard_nodes = []


# =====================================================================
#  Efeitos estilo anime (Storm): impacto, onda de choque, rachaduras,
#  destroços, aura, imagens residuais e rastro de arma
# =====================================================================
const BILL := preload("res://shaders/fx_billboard.gdshader")
const AURA := preload("res://shaders/aura.gdshader")
const GHOST := preload("res://shaders/ghost.gdshader")
const TRAIL := preload("res://shaders/trail.gdshader")

func _quality() -> String:
	return Save.opts.get("quality", "med")

func _sprite(texname: String, col: Color, size: float, billboard := true, intensity := 2.5) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new() if billboard else PlaneMesh.new()
	if q is QuadMesh: (q as QuadMesh).size = Vector2(1, 1)
	else: (q as PlaneMesh).size = Vector2(1, 1)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = BILL
	mat.set_shader_parameter("tex", tex("vfx:" + texname))
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("billboard", billboard)
	mat.set_shader_parameter("rot", randf() * TAU)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3.ONE * size
	add_child(m)
	return m

## Estrela de impacto de mangá (golpes fortes, críticos, finalizações).
func impact(pos: Vector3, col := Color(1, 0.75, 0.4), size := 1.6) -> void:
	var s1 := _sprite("impact_burst", col, size * 0.3)
	s1.global_position = pos
	var s2 := _sprite("spark_star6", Color(1, 1, 1), size * 0.4, true, 3.5)
	s2.global_position = pos
	var m1: ShaderMaterial = s1.material_override
	var m2: ShaderMaterial = s2.material_override
	custom(0.22, func(t, _dt):
		var f: float = t / 0.22
		var k := 1.0 - pow(1.0 - minf(1.0, f * 2.5), 3.0)
		s1.scale = Vector3.ONE * size * (0.3 + 0.9 * k)
		s2.scale = Vector3.ONE * size * (0.4 + 1.2 * k)
		m1.set_shader_parameter("alpha", 1.0 - smoothstep(0.45, 1.0, f))
		m2.set_shader_parameter("alpha", 1.0 - smoothstep(0.2, 0.7, f)), func():
		s1.queue_free()
		s2.queue_free())
	burst("star", pos, {"n": 4 if _quality() == "low" else 8, "color": col})

## Onda de choque no chão com anel, rachaduras, poeira e destroços.
func shockwave(pos: Vector3, col := Color(1, 0.8, 0.45), radius := 5.0, o := {}) -> void:
	var ring_s := _sprite("shock_ring", col, 0.5, false, 3.0)
	ring_s.global_position = Vector3(pos.x, pos.y + 0.08, pos.z)
	var rm: ShaderMaterial = ring_s.material_override
	var life: float = o.get("life", 0.5)
	custom(life, func(t, _dt):
		var f: float = t / life
		var e := 1.0 - pow(1.0 - f, 3.0)
		ring_s.scale = Vector3.ONE * (0.5 + radius * 2.0 * e)
		rm.set_shader_parameter("alpha", 1.0 - f * f), func(): ring_s.queue_free())
	if o.get("cracks", true):
		cracks(pos, radius * 0.55, o.get("glow", Color.BLACK))
	if o.get("debris", true):
		debris(pos, 6 if _quality() == "low" else 12, o.get("debris_col", Color(0.35, 0.3, 0.32)))
	for i in (8 if _quality() == "low" else 16):
		var a := i * TAU / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		emit("dust", pos + d * 0.6, d * randf_range(4, 8) + Vector3(0, randf_range(0.3, 1.2), 0), randf_range(0.5, 0.9), randf_range(0.6, 1.0), Color(0.8, 0.76, 0.72, 0.9))

## Rachaduras no chão (Decal); `glow` colore o brilho das fendas.
func cracks(pos: Vector3, size := 2.5, glow := Color.BLACK, life := 4.0) -> void:
	var d := Decal.new()
	d.size = Vector3(size * 2.0, 2.0, size * 2.0)
	# linha (branca, tingida pelo modulate) + brilho em escala de cinza (assume a cor do brilho)
	d.texture_albedo = tex("vfx:cracks_line")
	d.modulate = Color(0.08, 0.05, 0.1)
	if glow != Color.BLACK:
		d.texture_emission = tex("vfx:cracks_glow")
		d.emission_energy = 3.0
		d.modulate = glow
	d.albedo_mix = 0.95
	d.cull_mask = 1
	add_child(d)
	d.global_position = pos + Vector3(0, 0.5, 0)
	d.rotation.y = randf() * TAU
	custom(life, func(tt, _dt):
		var f: float = tt / life
		d.albedo_mix = 0.95 * (1.0 - smoothstep(0.6, 1.0, f))
		d.emission_energy = 3.0 * (1.0 - smoothstep(0.1, 0.6, f)), func(): d.queue_free())

var _rock_mesh: Mesh
## Pedaços de chão voando (física simples, quicam uma vez).
func debris(pos: Vector3, n := 10, col := Color(0.35, 0.3, 0.32)) -> void:
	if _rock_mesh == null:
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 0.7, 0.9)
		_rock_mesh = bm
	var mat := Toon.to_toon(_rock_material(col))
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = _rock_mesh
		m.material_override = mat
		var s := randf_range(0.08, 0.22)
		m.scale = Vector3.ONE * s
		add_child(m)
		m.global_position = pos + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
		var v := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(2, 6) + Vector3(0, randf_range(4, 9), 0)
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var vel := [v]
		var life := randf_range(1.0, 1.6)
		custom(life, func(t, dt):
			vel[0].y -= 22.0 * dt
			m.global_position += vel[0] * dt
			m.rotation += spin * dt
			if m.global_position.y < 0.05 and vel[0].y < 0.0:
				m.global_position.y = 0.05
				vel[0] = Vector3(vel[0].x * 0.4, -vel[0].y * 0.3, vel[0].z * 0.4)
			if t > life - 0.3:
				m.scale = Vector3.ONE * s * maxf(0.01, (life - t) / 0.3), func(): m.queue_free())

var _rock_mats := {}
func _rock_material(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if not _rock_mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		_rock_mats[k] = m
	return _rock_mats[k]

## Aura de poder em volta de um ator; devolve o nó (remover com aura_end).
func aura(actor: Node3D, col_a: Color, col_b: Color, intensity := 2.2) -> Node3D:
	var root: Node = actor.get("rig") if actor.get("rig") else actor
	var mat := ShaderMaterial.new()
	mat.shader = AURA
	mat.set_shader_parameter("noise_tex", tex("vfx:aura_noise"))
	mat.set_shader_parameter("col_a", col_a)
	mat.set_shader_parameter("col_b", col_b)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("alpha", 0.0)
	var meshes: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.material_overlay == null and not m3.get_meta("no_aura", false) and not (m3.material_override is ShaderMaterial and (m3.material_override as ShaderMaterial).shader == GHOST):
			m3.material_overlay = mat
			meshes.append(m3)
	# nó de controle: chamas e brasas subindo em volta do corpo
	var h: float = actor.get("height") if actor.get("height") else 1.8
	var node := Node3D.new()
	node.set_meta("mat", mat)
	node.set_meta("meshes", meshes)
	actor.add_child(node)
	var lo := _quality() == "low"
	var acc := [0.0]
	var it := custom(1.0e9, func(t, dt):
		if not is_instance_valid(node):
			return
		mat.set_shader_parameter("alpha", minf(1.0, t / 0.3) * float(node.get_meta("fade", 1.0)))
		acc[0] += dt
		var step := 0.07 if lo else 0.03
		while acc[0] > step:
			acc[0] -= step
			var a := randf() * TAU
			var r := randf_range(0.2, 0.45)
			var p: Vector3 = node.global_position + Vector3(cos(a) * r, randf_range(0.0, h * 0.8), sin(a) * r)
			emit("fire", p, Vector3(cos(a) * 0.3, randf_range(1.4, 2.6), sin(a) * 0.3), randf_range(0.35, 0.6), randf_range(0.35, 0.6), col_a.lerp(col_b, randf() * 0.4))
			if randf() < 0.35:
				emit("ember", p, Vector3(randf_range(-0.4, 0.4), randf_range(1.5, 3.0), randf_range(-0.4, 0.4)), 0.8, 0.12, col_b))
	node.set_meta("item", it)
	return node

func aura_end(m) -> void:
	if m == null or not is_instance_valid(m):
		return
	var node: Node3D = m
	var mat: ShaderMaterial = node.get_meta("mat")
	var it: Dictionary = node.get_meta("item")
	it.kill = true
	custom(0.35, func(t, _dt): mat.set_shader_parameter("alpha", 1.0 - t / 0.35), func():
		for mi in node.get_meta("meshes"):
			if is_instance_valid(mi) and mi.material_overlay == mat:
				mi.material_overlay = null
		node.queue_free())

## Imagem residual: cópia congelada da pose atual do personagem que some em `life`.
func afterimage(actor, col := Color(0.6, 0.3, 1.0), life := 0.35) -> void:
	if actor == null or not is_instance_valid(actor) or actor.get("rig") == null:
		return
	if _quality() == "low":
		return
	var mat := ShaderMaterial.new()
	mat.shader = GHOST
	mat.set_shader_parameter("color", col)
	var nodes := []
	for mi in actor.rig.find_children("*", "MeshInstance3D", true, false):
		var src: MeshInstance3D = mi
		if not src.is_visible_in_tree() or src.mesh == null or src.get_parent() is Cloth or src is Cloth:
			continue
		var mesh: Mesh = src.mesh
		if src.skin != null:
			if not (src.get_node_or_null(src.skeleton) is Skeleton3D) or src.get_skin_reference() == null:
				continue
			mesh = src.bake_mesh_from_current_skeleton_pose()
		if mesh == null:
			continue
		var g := MeshInstance3D.new()
		g.mesh = mesh
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		g.global_transform = src.global_transform
		nodes.append(g)
	custom(life, func(t, _dt): mat.set_shader_parameter("alpha", 0.8 * (1.0 - t / life)), func():
		for g in nodes:
			if is_instance_valid(g): g.queue_free())

## Rastro de arma/punho durante um golpe (segue a arma ou a mão por `dur` segundos).
func trail(rig, col: Color, dur := 0.3, bone := "hand_r") -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var tr := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	tr.mesh = im
	var mat := ShaderMaterial.new()
	mat.shader = TRAIL
	mat.set_shader_parameter("noise_tex", tex("vfx:aura_noise"))
	mat.set_shader_parameter("color", col)
	tr.material_override = mat
	tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tr)
	var hist: Array = []
	var w = rig.weapon if rig.weapon and is_instance_valid(rig.weapon) and bone == "hand_r" else null
	var tip_local := Vector3(0, 0.6, 0)
	var base_local := Vector3(0, 0.1, 0)
	if w:
		var bb := AABB()
		var first := true
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (w.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			bb = box if first else bb.merge(box)
			first = false
		var ax := bb.get_longest_axis()
		var c := bb.get_center()
		var half := bb.size[bb.get_longest_axis_index()] * 0.5
		tip_local = c + ax * half
		base_local = c - ax * half * 0.1
		if tip_local.length() < base_local.length():
			var tmp := tip_local; tip_local = base_local; base_local = tmp
	custom(dur + 0.2, func(t, _dt):
		if not is_instance_valid(rig):
			return
		if t < dur:
			var a: Vector3
			var b: Vector3
			if w and is_instance_valid(w):
				a = w.global_transform * base_local
				b = w.global_transform * tip_local
			else:
				a = rig.bone_world(bone.replace("hand", "lowerarm"))
				b = rig.bone_world(bone)
				b = b + (b - a).normalized() * 0.15
			hist.push_front([a, b, t])
		while hist.size() > 2 and t - hist[-1][2] > 0.2:
			hist.pop_back()
		im.clear_surfaces()
		if hist.size() < 2:
			return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in hist.size():
			var age: float = clampf((t - hist[i][2]) / 0.2, 0.0, 1.0)
			im.surface_set_uv(Vector2(age, 0.0))
			im.surface_add_vertex(hist[i][0])
			im.surface_set_uv(Vector2(age, 1.0))
			im.surface_add_vertex(hist[i][1])
		im.surface_end(), func(): tr.queue_free())

var _log_mat: Material
## Tronco da Substituição: fica no lugar do lutador, tomba e some.
func sub_log(pos: Vector3, face := 0.0) -> void:
	if _log_mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.42, 0.27, 0.15)
		_log_mat = Toon.to_toon(sm)
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	root.rotation.y = face
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.23
	cm.height = 1.5
	cm.radial_segments = 9
	var m := MeshInstance3D.new()
	m.mesh = cm
	m.material_override = _log_mat
	m.position = Vector3(0, 0.75, 0)
	root.add_child(m)
	# anel claro no topo (madeira cortada)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.17
	cap.bottom_radius = 0.17
	cap.height = 0.02
	var cmi := MeshInstance3D.new()
	cmi.mesh = cap
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.85, 0.68, 0.45)
	cmi.material_override = Toon.to_toon(cmat)
	cmi.position = Vector3(0, 1.51, 0)
	root.add_child(cmi)
	var side := 1.0 if randf() < 0.5 else -1.0
	var ref := [root]
	custom(1.4, func(t, _dt):
		var r: Node3D = ref[0]
		if not is_instance_valid(r):
			return
		var k := clampf((t - 0.25) / 0.45, 0.0, 1.0)
		r.rotation.z = side * k * k * 1.45
		if t > 1.1:
			r.scale = Vector3.ONE * maxf(0.01, (1.4 - t) / 0.3), func():
		var r: Node3D = ref[0]
		if is_instance_valid(r):
			burst("smoke", r.global_position + Vector3(0, 0.3, 0), {"n": 6, "r": 0.3})
			r.queue_free())

## Bloco de gelo em volta de um ator congelado (some ou estilhaça ao terminar).
func ice_block(actor: Node3D) -> Node3D:
	var h: float = actor.get("height") if actor.get("height") else 1.8
	var r: float = actor.get("radius") if actor.get("radius") else 0.45
	var root := Node3D.new()
	actor.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.86, 1.0, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.55, 0.85)
	mat.emission_energy_multiplier = 0.9
	mat.roughness = 0.05
	mat.metallic_specular = 1.0
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.rim_tint = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# cristais irregulares formando o bloco
	for k in 7:
		var m := MeshInstance3D.new()
		var pm := PrismMesh.new() if k % 2 else BoxMesh.new()
		if pm is BoxMesh:
			(pm as BoxMesh).size = Vector3(r * 1.6, h * randf_range(0.7, 1.05), r * 1.4)
		else:
			(pm as PrismMesh).size = Vector3(r * 1.3, h * randf_range(0.8, 1.15), r * 1.2)
		m.mesh = pm
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := k * TAU / 7.0
		m.position = Vector3(cos(a) * r * 0.35, h * 0.48, sin(a) * r * 0.35)
		m.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
		root.add_child(m)
	burst("ice", actor.global_position + Vector3(0, h * 0.5, 0), {"n": 16, "r": 0.4})
	Audio.sfx("ice", 0.8)
	root.scale = Vector3(1, 0.05, 1)
	var ref := [root]
	custom(0.18, func(t, _dt):
		if is_instance_valid(ref[0]): ref[0].scale = Vector3(1, maxf(0.05, t / 0.18), 1))
	return root

func ice_block_break(root: Node3D, shatter := false) -> void:
	if root == null or not is_instance_valid(root):
		return
	var p := root.global_position + Vector3(0, 0.9, 0)
	burst("ice", p, {"n": 40 if shatter else 18, "r": 0.5, "speed": 2.5 if shatter else 1.0})
	if shatter:
		burst("spark", p, {"n": 24, "color": Color(0.8, 0.95, 1.0), "color2": Color(0.3, 0.6, 1.0)})
		impact(p, Color(0.6, 0.9, 1.0), 2.4)
		Audio.sfx("shatter")
	else:
		Audio.sfx("ice", 0.5)
	root.queue_free()


# =====================================================================
#  Efeitos dos novos lutadores
# =====================================================================
## Tentáculo do Abismo saindo do chão (sobe, golpeia e afunda).
func ground_tentacle(pos: Vector3, h := 2.6, life := 0.9, lean := Vector3.ZERO) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.07)
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.16, 0.04, 0.2)
	mat.rim_enabled = true
	mat.rim = 0.6
	var segs: Array = []
	var n := 12
	for i in n:
		var r := 0.2 * (1.0 - float(i) / n) + 0.04
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 8; sm.rings = 5
		m.mesh = sm
		m.material_override = mat
		add_child(m)
		segs.append(m)
	var ph := randf() * 6.0
	burst("shadow", pos + Vector3(0, 0.3, 0), {"n": 10, "r": 0.5})
	burst("dust", pos, {"n": 8})
	custom(life, func(t, _dt):
		var k := clampf(t / 0.16, 0.0, 1.0) * (1.0 - smoothstep(life - 0.3, life, t))
		for i in n:
			var u := float(i) / (n - 1)
			var m: MeshInstance3D = segs[i]
			if not is_instance_valid(m): continue
			m.global_position = pos + Vector3(sin(u * 3.0 + ph + t * 6.0) * 0.18 * u, u * h * k, cos(u * 2.0 + ph) * 0.12 * u) + lean * u * u * k, func():
		for m in segs:
			if is_instance_valid(m): m.queue_free())

## Fio / vinha esticado entre dois pontos por `life` segundos (segue nós se forem passados).
func tether(a, b, col: Color, life := 0.6, width := 0.03) -> void:
	var m := laser()
	var mat: StandardMaterial3D = m.material_override
	mat.albedo_color = col * 2.5
	(m.mesh as CylinderMesh).top_radius = width
	(m.mesh as CylinderMesh).bottom_radius = width
	add_child(m)
	var ref := [m]
	custom(life, func(t, _dt):
		var pa: Vector3 = a.chest_pos() if a is Node3D and a.has_method("chest_pos") else (a.global_position if a is Node3D else a)
		var pb: Vector3 = b.chest_pos() if b is Node3D and b.has_method("chest_pos") else (b.global_position if b is Node3D else b)
		if is_instance_valid(ref[0]): place_beam(ref[0], pa, pb, 1.0 - t / life), func():
		if is_instance_valid(ref[0]): ref[0].queue_free())

## Nuvem de fumaça (bomba do Near): esconde e cega quem está dentro.
func smoke_cloud(pos: Vector3, radius := 3.0, life := 3.0) -> void:
	for k in 26:
		var a := randf() * TAU
		var r := randf() * radius
		emit("smoke", pos + Vector3(cos(a) * r, randf_range(0.2, 1.8), sin(a) * r), Vector3(randf_range(-0.3, 0.3), 0.15, randf_range(-0.3, 0.3)), life, randf_range(1.6, 2.6), Color(0.28, 0.25, 0.32, 0.95))
