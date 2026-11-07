class_name CamShots
## Tomadas de câmera relativas a atores (para Ultimates, finalizações e roteiro).

## Close no rosto do ator.
static func closeup(a, dist := 1.4, side := 0.4, fov := 36.0, dur := 2.0, h := 0.0, cut := true) -> Dictionary:
	var f: Vector3 = Game.fwd(a.yaw)
	var r := Vector3(-f.z, 0, f.x)
	var head: Vector3 = a.head_pos(-0.08 + h)
	var pos: Vector3 = head + f * dist + r * side
	return {"pos": pos, "look": head, "pos2": pos - f * 0.25, "look2": head, "fov": fov, "dur": dur, "cut": cut, "blend": 0.25}

## Ângulo baixo, de lado, enquadrando atacante e alvo (impacto).
static func low_angle(a, b, side := 1.0, dist := 3.2, fov := 52.0, dur := 1.2) -> Dictionary:
	var mid: Vector3 = a.global_position.lerp(b.global_position, 0.5)
	var dir: Vector3 = (b.global_position - a.global_position)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var right := Vector3(-dir.z, 0, dir.x) * side
	var pos := mid + right * dist + Vector3(0, 0.45, 0) - dir * 0.6
	var look := mid + Vector3(0, 1.2, 0)
	return {"pos": pos, "look": look, "pos2": pos + right * 0.4 + Vector3(0, 0.1, 0), "look2": look, "fov": fov, "fov2": fov - 6.0, "dur": dur, "cut": true}

## Versão com ângulo holandês (rolagem em radianos).
static func dutch(o: Dictionary, roll := 0.22) -> Dictionary:
	var d := o.duplicate()
	d["roll"] = roll
	return d

## Zoom de impacto: de aberto para fechado rapidamente.
static func crash_zoom(a, b, dur := 0.5) -> Dictionary:
	var o := low_angle(a, b, 1.0, 4.2, 70.0, dur)
	o["fov2"] = 32.0
	return o

## Ponto ao redor de um alvo, a um ângulo (rad) relativo ao yaw do alvo.
static func around(t, ang: float, dist := 3.0, h := 1.5, fov := 46.0, dur := 0.6, look_h := 1.1) -> Dictionary:
	var y: float = t.yaw + ang
	var c: Vector3 = t.global_position
	var pos := c + Vector3(sin(y), 0, cos(y)) * dist + Vector3(0, h, 0)
	var look := c + Vector3(0, look_h, 0)
	var tang := Vector3(cos(y), 0, -sin(y)) * 0.6
	return {"pos": pos, "look": look, "pos2": pos + tang, "look2": look, "fov": fov, "dur": dur, "cut": true}

## Órbita contínua em torno de um ponto.
static func orbit(center: Vector3, r: float, h: float, a0: float, a1: float, dur: float, look_h := 1.3, fov := 50.0) -> Dictionary:
	return {"pos": center, "look": center, "dur": dur, "blend": 0.0001, "fov": fov, "track": func(t: float) -> Dictionary:
		var a: float = a0 + (a1 - a0) * minf(1.0, t / dur)
		return {"pos": center + Vector3(sin(a) * r, h, cos(a) * r), "look": center + Vector3(0, look_h, 0)}}
