class_name Geo
## Utilidades de geometria procedural (tubos, mechas, cabeças, acessórios).

## Constrói um tubo ao longo de uma curva. radii: raio em cada ponto. flat: achata a seção
## (1 = redondo, <1 = lâmina). UV.x ao redor, UV.y ao longo (0 raiz → 1 ponta).
static func tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int = 6, flat: float = 1.0, up_hint := Vector3.UP, cap := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var frames_n: Array[Vector3] = []
	var frames_b: Array[Vector3] = []
	var t0 := (pts[1] - pts[0]).normalized()
	var nrm := t0.cross(up_hint)
	if nrm.length() < 0.01:
		nrm = t0.cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	for i in n:
		var t: Vector3
		if i == 0: t = (pts[1] - pts[0]).normalized()
		elif i == n - 1: t = (pts[n - 1] - pts[n - 2]).normalized()
		else: t = (pts[i + 1] - pts[i - 1]).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		frames_n.append(nrm)
		frames_b.append(t.cross(nrm).normalized())
	var base := 0
	var verts := []
	for i in n:
		var ring := []
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			var off := frames_n[i] * cos(a) * radii[i] * flat + frames_b[i] * sin(a) * radii[i]
			var nn: Vector3 = (frames_n[i] * cos(a) / maxf(flat, 0.2) + frames_b[i] * sin(a)).normalized()
			ring.append([pts[i] + off, nn, Vector2(float(s) / sides, float(i) / (n - 1))])
		verts.append(ring)
	for i in n - 1:
		for s in sides:
			var a = verts[i][s]; var b = verts[i][s + 1]; var c = verts[i + 1][s]; var d = verts[i + 1][s + 1]
			for v in [a, c, b, b, c, d]:
				st.set_normal(v[1]); st.set_uv(v[2]); st.add_vertex(v[0])
	if cap and radii[n - 1] > 0.002:
		var tip := pts[n - 1] + (pts[n - 1] - pts[n - 2]).normalized() * radii[n - 1]
		for s in sides:
			var a = verts[n - 1][s]; var b = verts[n - 1][s + 1]
			st.set_normal(a[1]); st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(tip)
			st.set_normal(b[1]); st.set_uv(b[2]); st.add_vertex(b[0])
			st.set_normal(a[1]); st.set_uv(a[2]); st.add_vertex(a[0])

static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var t := float(i) / (n - 1)
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out

static func taper(n: int, r0: float, r1: float, power := 1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		var t := pow(float(i) / (n - 1), power)
		out.append(lerpf(r0, r1, t))
	return out

# ---------------------------------------------------------------------
#  Cabeça
# ---------------------------------------------------------------------
## Forma da cabeça anime: elipsoide com queixo afinado. Retorna a posição na superfície.
static func head_point(theta: float, phi: float, r: Vector3) -> Vector3:
	# theta: 0 (topo) → PI (base); phi: ângulo ao redor (0 = frente +Z)
	var y := cos(theta)
	var s := sin(theta)
	var x := s * sin(phi)
	var z := s * cos(phi)
	var p := Vector3(x * r.x, y * r.y, z * r.z)
	if y < -0.05:
		var k: float = pow(clampf((-y - 0.05) / 0.95, 0.0, 1.0), 1.3)
		p.x *= lerpf(1.0, 0.42, k)
		if z > 0.0:
			p.z *= lerpf(1.0, 0.85, k)
			p.z += k * 0.012
		else:
			p.z *= lerpf(1.0, 0.55, k)
		p.y -= k * 0.012
	if z < 0.0 and y > -0.3:
		p.z *= 1.08
	if z > 0.0:
		p.z *= 0.94
	return p

static func head_mesh(r: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 26
	var cols := 36
	var grid := []
	for i in rows + 1:
		var th := PI * float(i) / rows
		var row := []
		for j in cols + 1:
			var ph := TAU * float(j) / cols
			row.append(head_point(th, ph, r))
		grid.append(row)
	for i in rows:
		for j in cols:
			var a: Vector3 = grid[i][j]; var b: Vector3 = grid[i][j + 1]; var c: Vector3 = grid[i + 1][j]; var d: Vector3 = grid[i + 1][j + 1]
			for v in [a, b, c, b, d, c]:
				st.set_uv(Vector2(float(j) / cols, float(i) / rows))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

## Ponto no couro cabeludo (um pouco acima da superfície), para enraizar mechas.
static func scalp(theta: float, phi: float, r: Vector3, lift := 0.004) -> Vector3:
	var p := head_point(theta, phi, r)
	return p + p.normalized() * lift

## Empurra um ponto para fora do elipsoide da cabeça (colisão das mechas).
static func push_out(p: Vector3, r: Vector3, margin := 0.012) -> Vector3:
	var rr := r + Vector3.ONE * margin
	var q := Vector3(p.x / rr.x, p.y / rr.y, p.z / rr.z)
	var l := q.length()
	if l < 1.0 and l > 0.0001:
		q = q / l
		return Vector3(q.x * rr.x, q.y * rr.y, q.z * rr.z)
	return p

## Faz crescer uma mecha: parte da raiz, segue uma direção, cai com gravidade, contorna a cabeça.
static func grow_strand(root: Vector3, dir: Vector3, length: float, r: Vector3, gravity: float, curl: Vector3, segs: int = 7, extra_col: Array = []) -> PackedVector3Array:
	var pts := PackedVector3Array([root])
	var p := root
	var d := dir.normalized()
	var seg := length / segs
	for i in segs:
		d = (d + Vector3(0, -gravity, 0) + curl * sin(float(i) * 0.9)).normalized()
		p += d * seg
		p = push_out(p, r, 0.006 + 0.004 * i)
		for c in extra_col:   # [centro, raio] esferas extras (ombros)
			var off: Vector3 = p - c[0]
			if off.length() < c[1]:
				p = c[0] + off.normalized() * c[1]
		pts.append(p)
	return pts

# ---------------------------------------------------------------------
#  Cabelos
# ---------------------------------------------------------------------
## style: dicionário com parâmetros. Retorna malha com UV.y raiz→ponta (para o shader de cabelo).
static func hair_mesh(style: Dictionary, r: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = style.get("seed", 7)
	var cap_bottom: float = style.get("cap_bottom", 1.7)    # theta máximo do "capacete" atrás
	# capacete de cabelo (cobre topo e nuca, deixa a testa livre)
	var hr := r * 1.04 + Vector3.ONE * 0.003
	var rows := 18
	var cols := 32
	var hairline: float = style.get("hairline", 0.95)       # theta da linha do cabelo na testa
	for i in rows:
		for j in cols:
			var verts := []
			for k in [[i, j], [i + 1, j], [i, j + 1], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
				var th := cap_bottom * float(k[0]) / rows
				var ph := TAU * float(k[1]) / cols
				var front: float = maxf(0.0, cos(ph))
				var lim: float = lerpf(cap_bottom, hairline, pow(front, 2.0))
				th = minf(th, lim)
				verts.append([head_point(th, ph, hr) * 1.0, Vector2(float(k[1]) / cols, th / cap_bottom * 0.35)])
			for v in verts:
				st.set_normal(v[0].normalized()); st.set_uv(v[1]); st.add_vertex(v[0])
	# mechas
	var strands: Array = style.get("strands", [])
	for group in strands:
		var count: int = group.get("count", 20)
		for s in count:
			var th: float = rng.randf_range(group.th[0], group.th[1])
			var ph: float = rng.randf_range(group.ph[0], group.ph[1])
			if group.get("mirror", false) and s % 2 == 1:
				ph = -ph
			var root := scalp(th, ph, hr, 0.0)
			var outward := root.normalized()
			var dir: Vector3 = (outward * group.get("out", 0.6) + group.get("dir", Vector3(0, -1, 0))).normalized()
			dir = (dir + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * group.get("jitter", 0.25)).normalized()
			var length: float = rng.randf_range(group.len[0], group.len[1])
			var curl: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)) * group.get("curl", 0.1)
			var segs: int = group.get("segs", 7)
			var pts := grow_strand(root, dir, length, hr, group.get("gravity", 0.25), curl, segs, style.get("colliders", []))
			var w: float = rng.randf_range(group.w[0], group.w[1])
			tube(st, pts, taper(pts.size(), w, group.get("tip", 0.002), group.get("taper", 1.2)), group.get("sides", 4), group.get("flat", 0.45), outward)
	# rabo de cavalo
	if style.has("ponytail"):
		var pt: Dictionary = style.ponytail
		var base: Vector3 = pt.pos
		for s in pt.get("count", 10):
			var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * 0.012
			var p0 := base + o
			var pts := Geo.bezier(p0, p0 + Vector3(0, -0.04, -0.06), p0 + Vector3(o.x * 2, -pt.len * 0.6, -0.1), p0 + Vector3(o.x * 3, -pt.len, -0.08 + rng.randf_range(-0.02, 0.02)), 8)
			tube(st, pts, taper(8, pt.get("w", 0.02), 0.003, 0.8), 5, 0.6, Vector3.BACK)
	return st.commit()

# ---------------------------------------------------------------------
#  Acessórios de cabeça
# ---------------------------------------------------------------------
static func ear_mesh(side: float, length: float, r: Vector3, tilt := 0.35) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Vector3(side * r.x * 0.96, -0.005, -0.008)
	var tip := base + Vector3(side * length * 0.85, length * tilt, -length * 0.45)
	var pts := Geo.bezier(base, base + Vector3(side * length * 0.3, 0.0, 0.0), tip - Vector3(side * length * 0.2, length * 0.1, -length * 0.1), tip, 7)
	tube(st, pts, taper(7, 0.024, 0.002, 0.9), 6, 0.35, Vector3.FORWARD)
	return st.commit()

static func ram_horn(side: float, scale := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 26
	for i in n:
		var t := float(i) / (n - 1)
		var a := t * 4.4
		var rad: float = lerpf(0.055, 0.02, t) * scale
		var p := Vector3(side * (0.02 + t * 0.07), 0.0, 0.0) + Vector3(0, sin(a) * rad * 1.6, -cos(a) * rad * 1.6 + rad * 1.6) * 1.0
		p += Vector3(side * 0.01 * t, 0.03 * t, -0.03 * t) * scale
		pts.append(p * scale + Vector3(0, 0, 0))
		radii.append(lerpf(0.024, 0.006, pow(t, 0.8)) * scale * (1.0 + 0.08 * sin(t * 60.0)))
	tube(st, pts, radii, 7, 1.0, Vector3(side, 0, 0))
	return st.commit()

static func dragon_horn(side: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3(0, 0, 0)
	var pts := Geo.bezier(p0, p0 + Vector3(side * 0.02, 0.05, -0.02), p0 + Vector3(side * 0.05, 0.09, -0.08), p0 + Vector3(side * 0.06, 0.08, -0.15), 9)
	tube(st, pts, taper(9, 0.018, 0.002, 1.0), 6, 0.8, Vector3(side, 0, 0))
	return st.commit()

static func antler(side: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3.ZERO
	var main := Geo.bezier(p0, p0 + Vector3(side * 0.03, 0.08, -0.01), p0 + Vector3(side * 0.1, 0.14, 0.0), p0 + Vector3(side * 0.13, 0.25, -0.03), 10)
	tube(st, main, taper(10, 0.013, 0.004, 1.0), 6, 1.0, Vector3(side, 0, 0))
	for b in [[0.35, Vector3(side * 0.06, 0.07, 0.03)], [0.6, Vector3(side * -0.01, 0.09, 0.0)], [0.8, Vector3(side * 0.07, 0.05, -0.02)]]:
		var i := int(b[0] * 9)
		var s := main[i]
		var e: Vector3 = s + b[1]
		tube(st, Geo.bezier(s, s + b[1] * 0.4 + Vector3(0, 0.01, 0), e - Vector3(0, 0.01, 0), e, 6), taper(6, 0.008, 0.003), 5, 1.0, Vector3(side, 0, 0))
	return st.commit()

static func tusk(side: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3(side * 0.028, -0.06, 0.07)
	tube(st, Geo.bezier(p0, p0 + Vector3(0, 0.015, 0.01), p0 + Vector3(side * 0.005, 0.03, 0.02), p0 + Vector3(side * 0.01, 0.042, 0.018), 6), taper(6, 0.008, 0.001), 6, 1.0, Vector3.FORWARD)
	return st.commit()

## Máscara de pano (Near): casca na metade inferior do rosto.
static func mask_mesh(r: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mr := r * 1.06 + Vector3.ONE * 0.004
	var rows := 10
	var cols := 18
	for i in rows:
		for j in cols:
			var quad := []
			for k in [[i, j], [i + 1, j], [i, j + 1], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
				var th: float = lerpf(1.62, 2.75, float(k[0]) / rows)
				var ph: float = lerpf(-1.75, 1.75, float(k[1]) / cols)
				quad.append(head_point(th, ph, mr))
			for v in quad:
				st.set_normal(v.normalized()); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(v)
	return st.commit()
